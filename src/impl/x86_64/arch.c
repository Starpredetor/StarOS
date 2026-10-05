#include "arch.h"

void arch_disable_interrupts(void) {
    __asm__ volatile ("cli");
}

void arch_halt(void) {
    /* cli so a pending interrupt cannot wake us, then hlt in a loop: a bare
     * hlt resumes on the next interrupt and falls through into whatever bytes
     * follow it. */
    __asm__ volatile ("cli");

    for (;;) {
        __asm__ volatile ("hlt");
    }
}
