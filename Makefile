# StarOS build.
# From inside that container:  make iso
# From the host (Linux/WSL):   make docker-iso

ARCH    := x86_64

ASM     := nasm

# Toolchain detection: prefer a real x86_64-elf cross-compiler when one is
# installed (the Docker buildenv has it), otherwise fall back to clang, which
# cross-compiles to any target out of the box. Override with
# `make CC=... LD=...` if you want something specific.
CROSS_CC := $(shell command -v $(ARCH)-elf-gcc 2>/dev/null)

ifeq ($(CROSS_CC),)
  CC          := clang --target=$(ARCH)-elf
  LD          := ld.lld
  # clang does not accept gcc's -mno-80387
  NO_FPU      := -mno-sse -mno-sse2 -mno-mmx
else
  CC          := $(ARCH)-elf-gcc
  LD          := $(ARCH)-elf-ld
  NO_FPU      := -mno-sse -mno-sse2 -mno-mmx -mno-80387
endif

# -mno-red-zone : the SysV red zone is unusable once interrupts exist
# $(NO_FPU)     : no FPU/SIMD state is set up in long mode yet, so the
#                 compiler must not emit those instructions
# -fno-pie/pic  : a kernel is loaded at a fixed address
# -MMD -MP      : emit header dependency files
CFLAGS  := -std=gnu11 -ffreestanding \
           -mno-red-zone $(NO_FPU) \
           -fno-pie -fno-pic -fno-stack-protector \
           -fno-strict-aliasing -fno-omit-frame-pointer \
           -Wall -Wextra -O2 -g \
           -I src/intf -MMD -MP

ASFLAGS := -f elf64 -g
LDFLAGS := -n -T targets/$(ARCH)/linker.ld

SRC_DIR   := src/impl
BUILD_DIR := build
DIST_DIR  := dist/$(ARCH)
ISO_DIR   := targets/$(ARCH)/iso

C_SOURCES   := $(shell find $(SRC_DIR)/kernel $(SRC_DIR)/$(ARCH) -name '*.c')
ASM_SOURCES := $(shell find $(SRC_DIR)/$(ARCH) -name '*.asm')

OBJECTS := $(patsubst $(SRC_DIR)/%.c,$(BUILD_DIR)/%.o,$(C_SOURCES)) \
           $(patsubst $(SRC_DIR)/%.asm,$(BUILD_DIR)/%.o,$(ASM_SOURCES))

KERNEL := $(DIST_DIR)/kernel.bin
ISO    := $(DIST_DIR)/kernel.iso

DOCKER_IMAGE := staros-buildenv

.PHONY: all iso run run-headless debug clean toolchain \
        docker-image docker-iso docker-shell

all: $(KERNEL)

# Prints what the build actually resolved to - check this first when a build
# fails in an unfamiliar environment.
toolchain:
	@echo "CC            = $(CC)"
	@echo "LD            = $(LD)"
	@echo "ASM           = $(ASM)"
	@echo "GRUB_MKRESCUE = $(GRUB_MKRESCUE)"
	@echo "QEMU          = $(QEMU)"

# ---------------------------------------------------------------- compilation

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm
	@mkdir -p $(dir $@)
	$(ASM) $(ASFLAGS) $< -o $@

$(KERNEL): $(OBJECTS) targets/$(ARCH)/linker.ld
	@mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $(OBJECTS)

# ------------------------------------------------------------------ bootable iso

iso: $(ISO)

# Fedora and openSUSE name it grub2-mkrescue; Debian and Arch use grub-mkrescue.
GRUB_MKRESCUE := $(shell command -v grub2-mkrescue 2>/dev/null \
                      || command -v grub-mkrescue 2>/dev/null \
                      || echo grub-mkrescue)

$(ISO): $(KERNEL) $(ISO_DIR)/boot/grub/grub.cfg
	@mkdir -p $(ISO_DIR)/boot
	cp $(KERNEL) $(ISO_DIR)/boot/kernel.bin
	$(GRUB_MKRESCUE) -o $@ $(ISO_DIR)

# ----------------------------------------------------------------------- qemu

QEMU       := qemu-system-$(ARCH)
QEMU_FLAGS := -cdrom $(ISO) -m 128M -serial stdio -no-reboot -no-shutdown

# Opens a VGA window. Kernel output currently goes to the screen, not serial.
run: $(ISO)
	$(QEMU) $(QEMU_FLAGS)

run-headless: $(ISO)
	$(QEMU) $(QEMU_FLAGS) -display none

# Halts before the first instruction and waits for gdb on :1234.
# In another shell:  gdb $(KERNEL) -ex 'target remote :1234'
debug: $(ISO)
	$(QEMU) $(QEMU_FLAGS) -s -S

# --------------------------------------------------------------------- docker

docker-image:
	docker build buildenv -t $(DOCKER_IMAGE)

docker-iso: docker-image
	docker run --rm -v "$(CURDIR)":/root/env $(DOCKER_IMAGE) make iso

docker-shell: docker-image
	docker run --rm -it -v "$(CURDIR)":/root/env $(DOCKER_IMAGE)

# ---------------------------------------------------------------------- clean

clean:
	rm -rf $(BUILD_DIR) dist $(ISO_DIR)/boot/kernel.bin

-include $(OBJECTS:.o=.d)
