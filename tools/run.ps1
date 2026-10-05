# Build StarOS in WSL, then boot it in QEMU on Windows.
#
# The repository stays on the Windows filesystem, so WSL builds it through
# /mnt/c and Windows QEMU reads the resulting ISO directly - one copy of the
# files, nothing to sync.
#
#   .\tools\run.ps1                 build and boot in a QEMU window
#   .\tools\run.ps1 -Headless       no window; serial output in this terminal
#   .\tools\run.ps1 -Gdb            halt at first instruction, wait for gdb :1234
#   .\tools\run.ps1 -NoBuild        boot the existing ISO without rebuilding
#   .\tools\run.ps1 -Distro Ubuntu  build in a specific WSL distro
#
# Note: without -Distro the build runs in your DEFAULT WSL distro, which is
# whatever `wsl --list --verbose` marks with an asterisk - not necessarily the
# one you installed the toolchain into.
#
# If PowerShell blocks the script:
#   powershell -ExecutionPolicy Bypass -File tools\run.ps1

[CmdletBinding()]
param(
    [switch]$Headless,

    # Not named -Debug: PowerShell reserves that as a common parameter.
    [switch]$Gdb,

    [switch]$NoBuild,
    [string]$Distro = ''
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$isoPath  = Join-Path $repoRoot 'dist\x86_64\kernel.iso'

function Find-Qemu {
    $onPath = Get-Command 'qemu-system-x86_64.exe' -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    $candidates = @(
        "$env:ProgramFiles\qemu\qemu-system-x86_64.exe",
        "${env:ProgramFiles(x86)}\qemu\qemu-system-x86_64.exe",
        "$env:LOCALAPPDATA\Programs\qemu\qemu-system-x86_64.exe"
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    return $null
}

# ----------------------------------------------------------------- build (WSL)

if (-not $NoBuild) {
    if (-not (Get-Command 'wsl.exe' -ErrorAction SilentlyContinue)) {
        throw 'wsl.exe not found. WSL is required to build the ISO.'
    }

    $distroArgs = @()
    if ($Distro) { $distroArgs = @('-d', $Distro) }

    # Translate C:\path\to\repo into /mnt/c/path/to/repo.
    #
    # Pass forward slashes to wslpath: backslashes are consumed as escape
    # characters on the way into the distro, so "C:\Users\me" arrives as
    # "C:Usersme" and wslpath fails.
    $repoRootFwd = $repoRoot -replace '\\', '/'

    $wslPath = (& wsl.exe @distroArgs wslpath -a "$repoRootFwd" 2>$null |
                Select-Object -First 1)

    # Strip NULs: some wsl.exe output arrives as UTF-16 and decodes with
    # embedded nulls.
    if ($wslPath) { $wslPath = ($wslPath -replace "`0", '').Trim() }

    if ([string]::IsNullOrWhiteSpace($wslPath) -or -not $wslPath.StartsWith('/')) {
        # Fall back to computing it ourselves. Correct for the default /mnt
        # mount root; only a custom root in /etc/wsl.conf would break it.
        if ($repoRoot -match '^([A-Za-z]):[\\/](.*)$') {
            $wslPath = '/mnt/' + $Matches[1].ToLower() + '/' + ($Matches[2] -replace '\\', '/')
            Write-Host "==> wslpath unavailable; using $wslPath" -ForegroundColor Yellow
        } else {
            throw "Could not translate '$repoRoot' to a WSL path."
        }
    }

    $distroLabel = if ($Distro) { $Distro } else { 'default distro' }
    Write-Host "==> Building in WSL [$distroLabel] at $wslPath" -ForegroundColor Cyan
    & wsl.exe @distroArgs -- bash -lc "cd '$wslPath' && make iso"
    if ($LASTEXITCODE -ne 0) {
        throw "WSL build failed (exit $LASTEXITCODE). Run 'bash tools/setup-wsl.sh' in WSL if the toolchain is missing."
    }
}

if (-not (Test-Path $isoPath)) {
    throw "ISO not found at $isoPath. Run without -NoBuild to build it."
}

# ------------------------------------------------------------------ run (QEMU)

$qemu = Find-Qemu
if (-not $qemu) {
    Write-Host 'QEMU for Windows was not found.' -ForegroundColor Yellow
    Write-Host 'Install it with:  winget install --id SoftwareFreedomConservancy.QEMU'
    throw 'qemu-system-x86_64.exe not available.'
}

$qemuArgs = @(
    '-cdrom', $isoPath,
    '-m', '128M',
    '-no-reboot',
    '-no-shutdown'
)

if ($Headless) {
    # Serial to this terminal; nothing is written to serial yet, so expect
    # silence until the serial driver lands.
    $qemuArgs += @('-display', 'none', '-serial', 'stdio')
} else {
    $qemuArgs += @('-serial', 'stdio')
}

if ($Gdb) {
    $qemuArgs += @('-s', '-S')
    Write-Host '==> Waiting for gdb on localhost:1234' -ForegroundColor Cyan
    Write-Host "    gdb dist/x86_64/kernel.bin -ex 'target remote :1234'"
}

Write-Host "==> Booting $([System.IO.Path]::GetFileName($isoPath))" -ForegroundColor Cyan
& $qemu @qemuArgs
exit $LASTEXITCODE
