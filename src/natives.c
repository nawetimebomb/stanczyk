#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

#include "common.h"
#include "object.h"
#include "value.h"
#include "vm.h"
#include "natives.h"

static value_t _randrange(int argc, value_t *args) {
    if (!IS_INT(args[0]) && !IS_INT(args[1])) {
        runtime_throw("randrange: arguments must be Int.");
    }

    int max = AS_INT(pop());
    int min = AS_INT(pop());
    int random = min + (rand() % (max - min));

    return INT_VAL(random);
}

static value_t _system(int argc, value_t *args) {
    if (!IS_STRING(args[0]))
        runtime_throw("system: argument must be a string.");
    return system(AS_CSTRING(args[0])) ? BOOL_VAL(false) : BOOL_VAL(true);
}

static value_t _length(int argc, value_t *args) {
    value_t value = args[0];
    if (!IS_LIST(value) && !IS_STRING(value))
        runtime_throw("length: argument must be list or strings.");

    return INT_VAL((IS_LIST(value)) ? AS_LIST(value)->count : strlen(AS_CSTRING(value)));
}

static value_t _append(int argc, value_t *args) {
    if (!IS_LIST(args[0]))
        runtime_throw("first argument has to be a list.");
    list_t *list = AS_LIST(args[0]);
    value_t value = args[1];
    return BOOL_VAL(list_append(list, value));
}

static value_t _delete(int argc, value_t *args) {
    if (!IS_LIST(args[0]))
        runtime_throw("first argument has to be a list.");
    if (!IS_INT(args[1]))
        runtime_throw("second argument has to be an int.");

    list_t *list = AS_LIST(args[0]);
    int index = AS_INT(args[1]);

    if (!list_is_valid_index(list, index))
        return BOOL_VAL(false);

    return BOOL_VAL(list_delete(list, index));
}

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

    char *buffer = (char *)malloc(file_size);
    if (buffer == NULL) {
        fprintf(stderr, "not enough memory to read file '%s'", path);
        return NIL_VAL;
    }

    size_t bytes_read = fread(buffer, sizeof(char), file_size, file);
    if (bytes_read < file_size) {
        fprintf(stderr, "could not read file \"%s\".\n", path);
        return NIL_VAL;
    }

    if (buffer[file_size - 1] == 10)
        file_size--;

    value_t result = OBJ_VAL(copy_string(buffer, file_size));
    fclose(file);
    free(buffer);

    return result;
}

static value_t _clock(int argc, value_t *args) {
    return FLOAT_VAL((double)clock() / CLOCKS_PER_SEC);
}

void register_natives(define_native_func define) {
    srand(time(NULL));
    // GENERAL
    define("clock",     _clock,     0);
    define("fread",     _fread,     1);
    define("system",    _system,    1);
    define("randrange", _randrange, 2);

    // LIST
    define("append",    _append,    2);
    define("delete",    _delete,    2);
    define("length",    _length,    1);
}
