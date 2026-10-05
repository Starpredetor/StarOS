#include "panic.h"

#include "arch.h"
#include "print.h"

void panic(const char *message, const char *file, const char *line) {
    /* Interrupts off first: a handler firing mid-panic would overwrite the
     * message we are trying to show. */
    arch_disable_interrupts();

    print_set_color(PRINT_COLOR_WHITE, PRINT_COLOR_RED);
    print_str("\nKERNEL PANIC\n");

    print_set_color(PRINT_COLOR_WHITE, PRINT_COLOR_BLACK);
    print_str(message);
    print_str("\n  at ");
    print_str(file);
    print_str(":");
    print_str(line);
    print_str("\n\nSystem halted.\n");

    arch_halt();
}
