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

procedure_t *new_procedure() {
    procedure_t *procedure = ALLOCATE_OBJ(procedure_t, OBJ_PROCEDURE);
    procedure->arity = 0;
    procedure->name = NULL;
    init_chunk(&procedure->chunk);
    return procedure;
}

native_t *new_native(native_proc_t procedure, int arg_count) {
    native_t *native = ALLOCATE_OBJ(native_t, OBJ_NATIVE);
    native->call = procedure;
    native->arity = arg_count;
    return native;
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

static void print_procedure(procedure_t *procedure) {
    if (procedure->name == NULL) {
        printf("<PROGRAM>");
        return;
    }

    printf("<procedure %s>", procedure->name->chars);
}

void print_obj(value_t value) {
    switch (OBJ_TYPE(value)) {
        case OBJ_PROCEDURE: print_procedure(AS_PROCEDURE(value)); break;
        case OBJ_NATIVE:    printf("<native procedure>");         break;
        case OBJ_STRING:    printf("%s", AS_CSTRING(value));      break;
    }
}
