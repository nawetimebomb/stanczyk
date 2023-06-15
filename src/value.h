#ifndef NLISP_VALUE_H
#define NLISP_VALUE_H

#include "common.h"

typedef struct obj_t obj_t;
typedef struct string_t string_t;

typedef enum {
    VAL_BOOL,
    VAL_NIL,
    VAL_FLOAT,
    VAL_INT,
    VAL_OBJ
} value_type_t;

typedef struct {
    value_type_t type;
    union {
        bool    boolean;
        double  f;
        long    i;
        obj_t   *obj;
    } as;
} value_t;

#define IS_BOOL(value)   ((value).type == VAL_BOOL)
#define IS_NIL(value)    ((value).type == VAL_NIL)
#define IS_FLOAT(value)  ((value).type == VAL_FLOAT)
#define IS_INT(value)    ((value).type == VAL_INT)
#define IS_NUMBER(value) (IS_FLOAT(value) || IS_INT(value))
#define IS_OBJ(value)    ((value).type == VAL_OBJ)

#define AS_BOOL(value)  ((value).as.boolean)
#define AS_FLOAT(value) ((value).as.f)
#define AS_INT(value)   ((value).as.i)
#define AS_OBJ(value)   ((value).as.obj)

#define NIL_VAL          ((value_t) {VAL_NIL,   {.i   = 0}})
#define BOOL_VAL(value)  ((value_t) {VAL_BOOL,  {.boolean = value}})
#define FLOAT_VAL(value) ((value_t) {VAL_FLOAT, {.f     = value}})
#define INT_VAL(value)   ((value_t) {VAL_INT,   {.i     = value}})
#define OBJ_VAL(object)  ((value_t) {VAL_OBJ,   {.obj      = (obj_t*)object}})

typedef struct {
    int capacity;
    int count;
    value_t *values;
} value_array_t;

void init_value_array(value_array_t *array);
void write_value_array(value_array_t *array, value_t value);
void free_value_array(value_array_t *array);
bool values_equal(value_t a, value_t b);
void print_value(value_t value);

#endif
