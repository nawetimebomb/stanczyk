#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "common.h"
#include "object.h"
#include "value.h"
#include "vm.h"
#include "natives.h"

static value_t _fread(int argc, value_t *args) {
    char *path = AS_CSTRING(args[0]);
    FILE *file = fopen(path, "rb");

    if (file == NULL) {
        fprintf(stderr, "could not open file '%s'\n", path);
        return NIL_VAL;
    }

    fseek(file, 0L, SEEK_END);
    size_t file_size = ftell(file);
    rewind(file);

    char *buffer = (char *)malloc(file_size + 1);
    size_t bytes_read = fread(buffer, sizeof(char), file_size, file);
    buffer[bytes_read] = '\0';
    value_t fcontents = OBJ_VAL(copy_string(buffer, file_size + 1));
    fclose(file);
    free(buffer);

    return fcontents;
}

static value_t _clock(int argc, value_t *args) {
    return NUMBER_VAL((double)clock() / CLOCKS_PER_SEC);
}

void register_natives(define_native_func define) {
    define("clock", _clock, 0);
    define("fread", _fread, 1);
}
