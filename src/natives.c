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

static value_t _strtobuf(int argc, value_t *args) {
    if (!IS_STRING(args[0]))
        runtime_throw("argument needs to be a string.");
    char *source = AS_CSTRING(args[0]);
    list_t *result = new_list();

    for (int i = 0; i < strlen(source); i++) {
        list_append(result, OBJ_VAL(copy_string(&source[i], 1)));
    }

    return OBJ_VAL(result);
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
    // GENERAL
    define("clock",    _clock,    0);
    define("fread",    _fread,    1);

    // LIST
    define("strtobuf", _strtobuf, 1);
    define("append",   _append,   2);
    define("delete",   _delete,   2);

}
