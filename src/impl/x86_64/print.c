#include "print.h"

/* VGA text mode console.
 *
 * 0xb8000 is a hardware-mapped buffer of NUM_COLS x NUM_ROWS cells, two bytes
 * each: one character byte, one attribute byte (low nibble foreground, high
 * nibble background). Writing to it updates the screen immediately.
 */

#define VGA_BUFFER_ADDRESS 0xb8000

static const size_t NUM_COLS = 80;
static const size_t NUM_ROWS = 25;

struct Char {
    uint8_t character;
    uint8_t color;
};

_Static_assert(sizeof(struct Char) == 2, "VGA cell must be exactly two bytes");

/* volatile: these writes are observable side effects on hardware, so the
 * compiler must not reorder, merge, or elide them. */
static volatile struct Char *const buffer =
    (volatile struct Char *) VGA_BUFFER_ADDRESS;

/* static: console state is private to this translation unit. */
static size_t col = 0;
static size_t row = 0;
static uint8_t color = PRINT_COLOR_WHITE | PRINT_COLOR_BLACK << 4;

static void clear_row(size_t clear_target) {
    const struct Char empty = {
        .character = ' ',
        .color = color,
    };

    for (size_t c = 0; c < NUM_COLS; c++) {
        buffer[c + NUM_COLS * clear_target] = empty;
    }
}

void print_clear(void) {
    for (size_t i = 0; i < NUM_ROWS; i++) {
        clear_row(i);
    }

    col = 0;
    row = 0;
}

void print_newline(void) {
    col = 0;

    if (row < NUM_ROWS - 1) {
        row++;
        return;
    }

    /* Bottom row reached: scroll every line up by one. */
    for (size_t r = 1; r < NUM_ROWS; r++) {
        for (size_t c = 0; c < NUM_COLS; c++) {
            buffer[c + NUM_COLS * (r - 1)] = buffer[c + NUM_COLS * r];
        }
    }

    clear_row(NUM_ROWS - 1);
}

void print_char(char character) {
    if (character == '\n') {
        print_newline();
        return;
    }

    /* >= not >: at col == NUM_COLS the next write would land on the following
     * row's first cell. */
    if (col >= NUM_COLS) {
        print_newline();
    }

    buffer[col + NUM_COLS * row] = (struct Char) {
        .character = (uint8_t) character,
        .color = color,
    };

    col++;
}

void print_str(const char *string) {
    for (size_t i = 0; string[i] != '\0'; i++) {
        print_char(string[i]);
    }
}

void print_set_color(uint8_t foreground, uint8_t background) {
    color = (uint8_t) (foreground | background << 4);
}
