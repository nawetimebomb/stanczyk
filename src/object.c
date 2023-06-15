#include <stdio.h>
#include <string.h>

#include "memory.h"
#include "object.h"
#include "table.h"
#include "value.h"
#include "vm.h"

extern VM_t VM;

#define ALLOCATE_OBJ(type, object_type_prop)                \
    (type *)allocate_object(sizeof(type), object_type_prop)

static obj_t *allocate_object(size_t size, obj_type_t type) {
    obj_t *object = (obj_t *)reallocate(NULL, 0, size);
    object->type = type;
    object->next = VM.objects;
    VM.objects = object;
    return object;
}

static string_t *allocate_string(char *chars, int length, uint32_t hash) {
    string_t *string = ALLOCATE_OBJ(string_t, OBJ_STRING);
    string->length = length;
    string->chars = chars;
    string->hash = hash;
    table_set(&VM.strings, string, NIL_VAL);
    return string;
}

static uint32_t hash_string(const char *key, int length) {
    uint32_t hash = 2166136261u;
    for (int i = 0; i < length; i++) {
        hash ^= (uint8_t)key[i];
        hash *= 16777619;
    }
    return hash;
}

string_t *take_string(char *chars, int length) {
    uint32_t hash = hash_string(chars, length);
    string_t *interned = table_find_string(&VM.strings, chars, length, hash);
    if (interned != NULL) {
        FREE_ARRAY(char, chars, length + 1);
        return interned;
    }
    return allocate_string(chars, length, hash);
}

string_t *copy_string(const char *chars, int length) {
    uint32_t hash = hash_string(chars, length);
    string_t *interned = table_find_string(&VM.strings, chars, length, hash);
    if (interned != NULL) return interned;
    char *heap = ALLOCATE(char, length + 1);
    memcpy(heap, chars, length);
    heap[length] = '\0';
    return allocate_string(heap, length, hash);
}

void print_obj(value_t value) {
    switch (OBJ_TYPE(value)) {
        case OBJ_STRING: printf("%s", AS_CSTRING(value)); break;
    }
}
