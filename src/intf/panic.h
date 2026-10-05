#pragma once

/* Unrecoverable-error reporting.
 *
 * Use PANIC when the kernel has reached a state it cannot continue from, and
 * KASSERT for invariants that must hold. Both print the source location and
 * halt the CPU - they never return, so there is no "panic and carry on".
 *
 *     PANIC("no usable memory region found");
 *     KASSERT(page_aligned(addr));
 *
 * The line number is stringified at compile time, which is why panic() takes
 * it as a string: the kernel has no integer formatting yet.
 */

__attribute__((noreturn))
void panic(const char *message, const char *file, const char *line);

#define PANIC_STRINGIFY_(x) #x
#define PANIC_STRINGIFY(x)  PANIC_STRINGIFY_(x)

#define PANIC(message) \
    panic((message), __FILE__, PANIC_STRINGIFY(__LINE__))

#define KASSERT(condition)                                   \
    do {                                                     \
        if (!(condition)) {                                  \
            panic("assertion failed: " #condition,           \
                  __FILE__, PANIC_STRINGIFY(__LINE__));      \
        }                                                    \
    } while (0)
