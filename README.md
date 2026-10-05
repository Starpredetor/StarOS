# StarOS

A small x86_64 kernel written from scratch in C and assembly. GRUB loads it via
multiboot2 in 32-bit protected mode; the boot code brings the CPU up into 64-bit
long mode and hands off to C.

**Status:** boots to 64-bit long mode, prints to a VGA text console, panics
loudly on unrecoverable errors. No interrupts, memory manager, or user mode yet.

## Building and running

Output lands in `dist/x86_64/kernel.iso`. The ISO is bootable on real hardware,
not just in an emulator.

### Windows (build in WSL, run in Windows QEMU)

A GRUB ISO cannot be produced on native Windows, and QEMU's `-kernel` loader
only understands multiboot 1, so the build runs in WSL while QEMU runs on
Windows. The repository stays on the Windows filesystem: WSL builds it through
`/mnt/c` and QEMU reads the ISO directly, so there is only ever one copy.

One-time setup, inside WSL:

```sh
bash tools/setup-wsl.sh
```

On Windows, install QEMU once:

```powershell
winget install --id SoftwareFreedomConservancy.QEMU
```

Then, from a Windows terminal in the repository root:

```powershell
.\tools\run.ps1              # build in WSL, boot in a QEMU window
.\tools\run.ps1 -Headless    # no window; serial on stdio
.\tools\run.ps1 -Gdb         # halt at first instruction, wait for gdb on :1234
.\tools\run.ps1 -NoBuild     # boot the existing ISO without rebuilding
```

Without `-Distro`, the build runs in your **default** WSL distro. Check which
that is with `wsl --list --verbose` (the one marked `*`) and pass
`-Distro <name>` if the toolchain lives in a different one.

### Linux / WSL only

```sh
bash tools/setup-wsl.sh      # once
make iso
make run                     # VGA window
make run-headless            # no window; serial on stdio
make debug                   # wait for gdb on :1234
```

### Docker

Useful for a pinned, reproducible toolchain (and what CI uses):

```sh
make docker-iso              # build the image if needed, then produce the ISO
make docker-shell            # interactive shell with the toolchain
```

### Toolchain

`make` prefers an `x86_64-elf-gcc` cross-compiler when one is installed and
otherwise falls back to `clang --target=x86_64-elf` with `ld.lld`, which needs
no cross-toolchain build. To see what was actually selected:

```sh
make toolchain
```

### Debugging

While `make debug` or `.\tools\run.ps1 -Debug` is waiting:

```sh
gdb dist/x86_64/kernel.bin -ex 'target remote :1234'
```

## How it boots

| Stage | Code | Mode |
|---|---|---|
| GRUB finds the multiboot2 header and loads the kernel at 1 MiB | `boot/header.asm` | — |
| Verify multiboot, CPUID and long-mode support | `boot/main.asm` | 32-bit protected |
| Identity-map the first 1 GiB with 2 MiB huge pages | `boot/main.asm` | 32-bit protected |
| Enable PAE, set EFER.LME, enable paging, load the 64-bit GDT | `boot/main.asm` | → compatibility |
| Far jump into the 64-bit code segment | `boot/main.asm` | 64-bit long |
| Zero the data segment registers, call into C | `boot/main64.asm` | 64-bit long |
| Kernel entry point | `kernel/main.c` | 64-bit long |

Paging is enabled before long mode because long mode requires it — not as a
memory-management feature. The kernel is identity-mapped, so virtual and
physical addresses are currently the same.

## Layout

```
src/
  impl/
    kernel/          architecture-independent kernel code
      main.c         kernel entry point
      panic.c        unrecoverable error reporting
    x86_64/
      boot/          multiboot header and the long-mode transition
      arch.c         x86_64 implementation of the arch interface
      print.c        VGA text console
  intf/              public headers (the interfaces above)
targets/x86_64/
  linker.ld          kernel memory layout
  iso/               GRUB configuration staged into the ISO
buildenv/            Dockerfile for the cross-toolchain
tools/
  setup-wsl.sh       one-time toolchain install on a Linux/WSL host
  run.ps1            Windows: build via WSL, boot via Windows QEMU
```

Code under `src/impl/kernel` must stay architecture-independent and call through
the interfaces in `src/intf` — no inline assembly or port I/O there.

## Error handling

`PANIC` and `KASSERT` (in `src/intf/panic.h`) report a message with its source
location and halt the CPU:

```c
PANIC("no usable memory region found");
KASSERT(page_aligned(address));
```

Neither returns. Since there is no integer formatting yet, the line number is
stringified at compile time.

## Roadmap

- [x] 64-bit long mode, VGA console, panic/assert
- [ ] Serial (COM1) driver so output is machine-readable and greppable
- [ ] Port I/O helpers, GDT and IDT, interrupt handlers
- [ ] Pass the multiboot memory map through to the kernel
- [ ] Physical page allocator, then a kernel heap
- [ ] PS/2 keyboard driver
- [ ] Interactive kernel shell
