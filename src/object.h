#ifndef NLISP_OBJECT_H
#define NLISP_OBJECT_H

#include "common.h"
#include "value.h"

#define OBJ_TYPE(value)  (AS_OBJ(value)->type)
#define IS_STRING(value) is_obj_type(value, OBJ_STRING)

#define AS_STRING(value)  ((string_t *)AS_OBJ(value))
#define AS_CSTRING(value) (((string_t *)AS_OBJ(value))->chars)

typedef enum {
    OBJ_STRING
} obj_type_t;

struct obj_t {
    obj_type_t type;
    struct obj_t *next;
};

struct string_t {
    obj_t obj;
    int length;
    char *chars;
    uint32_t hash;
};

string_t *take_string(char *chars, int length);
string_t *copy_string(const char *chars, int length);
void print_obj(value_t value);

static inline bool is_obj_type(value_t value, obj_type_t type) {
    return IS_OBJ(value) && AS_OBJ(value)->type == type;
}

#endif
