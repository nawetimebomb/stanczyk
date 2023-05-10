#ifdef _WIN32
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "cli_windows.h"

static char buffer[2048];

char *readline(const char *prompt) {
    char *result = malloc(strlen(buffer)+1);
    fputs(prompt, stdout);
    fgets(buffer, 2048, stdin);
    strcpy(result, buffer);
    // cstring terminated in 0
    result[strlen(result)-1] = '\0';

    return result;
}

// This is a stub function. In Linux, we want to use add_history from reaedline,
// but for Windows, we don't care because the console should handle it already.
void add_history(const char *discard) {}
#else

// This is empty for any other system because those are handled in main.c
// The stub function below makes my -pedantic compiler happy. I love you GCC :^)
void stub(){}

#endif
