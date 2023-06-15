#ifndef NLISP_OBJECT_H
#define NLISP_OBJECT_H

#include "common.h"
#include "chunk.h"
#include "value.h"

#define OBJ_TYPE(value)     (AS_OBJ(value)->type)
#define IS_PROCEDURE(value) is_obj_type(value, OBJ_PROCEDURE)
#define IS_NATIVE(value)    is_obj_type(value, OBJ_NATIVE)
#define IS_LIST(value)      is_obj_type(value, OBJ_LIST)
#define IS_STRING(value)    is_obj_type(value, OBJ_STRING)

#define AS_PROCEDURE(value) ((procedure_t *)AS_OBJ(value))
#define AS_NATIVE(value)    ((native_t *)AS_OBJ(value))
#define AS_LIST(value)      ((list_t *)AS_OBJ(value))
#define AS_STRING(value)    ((string_t *)AS_OBJ(value))
#define AS_CSTRING(value)   (((string_t *)AS_OBJ(value))->chars)

typedef enum {
    OBJ_PROCEDURE,
    OBJ_NATIVE,
    OBJ_LIST,
    OBJ_STRING
} obj_type_t;

struct obj_t {
    obj_type_t type;
    struct obj_t *next;
};

typedef struct {
    obj_t obj;
    int arity;
    chunk_t chunk;
    string_t *name;
} procedure_t;

typedef value_t (*native_proc_t)(int arg_count, value_t *args);

typedef struct {
    obj_t obj;
    int arity;
    native_proc_t call;
} native_t;

typedef struct {
    obj_t    obj;
    int      count;
    int      capacity;
    value_t  *content;
} list_t;

struct string_t {
    obj_t obj;
    int length;
    char *chars;
    uint32_t hash;
};

procedure_t *new_procedure();
native_t    *new_native(native_proc_t procedure, int arg_count);
list_t      *new_list();
bool         list_append(list_t *list, value_t value);
void         list_put(list_t *list, int index, value_t value);
value_t      list_get_index(list_t *list, int index);
bool         list_delete(list_t *list, int index);
bool         list_is_valid_index(list_t *list, int index);
string_t    *take_string(char *chars, int length);
string_t    *copy_string(const char *chars, int length);
void         print_obj(value_t value);

static inline bool is_obj_type(value_t value, obj_type_t type) {
    return IS_OBJ(value) && AS_OBJ(value)->type == type;
}

#endif
