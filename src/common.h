#ifndef NLISP_COMMON_H
#define NLISP_COMMON_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define DEBUG_PRINT_CODE
#define DEBUG_TRACE_EXECUTION

#define UINT8_COUNT (UINT8_MAX + 1)

// TODO: Move to a printer file
#define COLOR_RED "\033[31m"
#define STYLE_BOLD "\033[1m"
#define STYLE_ITALIC "\033[3m"
#define STYLE_OFF   "\033[m"


#endif
