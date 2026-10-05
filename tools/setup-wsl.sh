#!/usr/bin/env bash
# One-time toolchain setup inside a WSL distro (or any Linux box).
#
# Installs what `make iso` needs: a compiler that can target bare-metal
# x86_64, nasm, and the GRUB/xorriso tooling that builds the bootable ISO.
# QEMU is deliberately NOT installed here - on the hybrid Windows setup it
# runs natively on the Windows side.
#
# Usage:  bash tools/setup-wsl.sh

set -euo pipefail

say() { printf '\n==> %s\n' "$*"; }

if command -v dnf >/dev/null 2>&1; then
	say "Fedora-family detected (dnf)"
	sudo dnf install -y \
		clang lld llvm \
		nasm make \
		grub2-tools grub2-tools-extra grub2-pc-modules \
		xorriso mtools
elif command -v apt-get >/dev/null 2>&1; then
	say "Debian-family detected (apt)"
	sudo apt-get update
	sudo apt-get install -y \
		clang lld llvm \
		nasm make \
		grub-common grub-pc-bin \
		xorriso mtools
elif command -v pacman >/dev/null 2>&1; then
	say "Arch-family detected (pacman)"
	sudo pacman -Sy --needed --noconfirm \
		clang lld llvm \
		nasm make \
		grub \
		libisoburn mtools
else
	echo "Unrecognised package manager. Install manually:" >&2
	echo "  clang, lld, nasm, make, grub (BIOS modules), xorriso, mtools" >&2
	exit 1
fi

say "Verifying"
missing=0
for tool in clang ld.lld nasm make xorriso; do
	printf '  %-12s ' "$tool"
	if command -v "$tool" >/dev/null 2>&1; then
		echo "ok"
	else
		echo "MISSING"
		missing=1
	fi
done

printf '  %-12s ' "grub-mkrescue"
if command -v grub2-mkrescue >/dev/null 2>&1; then
	echo "ok (grub2-mkrescue)"
elif command -v grub-mkrescue >/dev/null 2>&1; then
	echo "ok (grub-mkrescue)"
else
	echo "MISSING"
	missing=1
fi

if [ "$missing" -ne 0 ]; then
	say "Some tools are missing - see above"
	exit 1
fi

say "Done. Build with:  make iso"
