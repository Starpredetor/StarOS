global long_mode_start
extern kernel_main

section .text
bits 64
long_mode_start:
    ; load null into all data segment registers
    mov ax, 0
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

	call kernel_main

    ; kernel_main returning is not expected, but if it does, stop cleanly
    ; rather than executing past the end of this function.
.hang:
    cli
    hlt
    jmp .hang