#pragma once

/* Operations every architecture must provide.
 *
 * Architecture-independent kernel code (anything under src/impl/kernel) calls
 * through this header and must never contain inline assembly or port I/O of
 * its own. The x86_64 implementation is src/impl/x86_64/arch.c.
 */

/* Mask maskable interrupts on the current CPU. */
void arch_disable_interrupts(void);

/* Stop this CPU permanently. Never returns. */
__attribute__((noreturn)) void arch_halt(void);
