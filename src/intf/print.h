#pragma once

#include <stdint.h>
#include <stddef.h>

/* VGA text mode console. Implementation: src/impl/x86_64/print.c
 *
 * This is an x86-specific backend. Architecture-independent code should go
 * through a generic console layer once one exists, not call these directly.
 */

enum {
	PRINT_COLOR_BLACK = 0,
	PRINT_COLOR_BLUE = 1,
	PRINT_COLOR_GREEN = 2,
	PRINT_COLOR_CYAN = 3,
	PRINT_COLOR_RED = 4,
	PRINT_COLOR_MAGENTA = 5,
	PRINT_COLOR_BROWN = 6,
	PRINT_COLOR_LIGHT_GRAY = 7,
	PRINT_COLOR_DARK_GRAY = 8,
	PRINT_COLOR_LIGHT_BLUE = 9,
	PRINT_COLOR_LIGHT_GREEN = 10,
	PRINT_COLOR_LIGHT_CYAN = 11,
	PRINT_COLOR_LIGHT_RED = 12,
	PRINT_COLOR_PINK = 13,
	PRINT_COLOR_YELLOW = 14,
	PRINT_COLOR_WHITE = 15,
};

/* Blanks the screen and moves the cursor to the top left. */
void print_clear(void);

void print_char(char character);
void print_newline(void);
void print_str(const char *string);

/* Applies to characters printed from here on, not to what is already shown. */
void print_set_color(uint8_t foreground, uint8_t background);
