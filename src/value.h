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
    VAL_OBJ,
} value_type_t;

typedef struct {
    value_type_t type;
    union {
        bool Bool;
        double Float;
        long Int;
        obj_t *Obj;
    } as;
} value_t;

#define IS_BOOL(value)   ((value).type == VAL_BOOL)
#define IS_NIL(value)    ((value).type == VAL_NIL)
#define IS_FLOAT(value)  ((value).type == VAL_FLOAT)
#define IS_INT(value)    ((value).type == VAL_INT)
#define IS_NUMBER(value) (IS_FLOAT(value) || IS_INT(value))
#define IS_OBJ(value) ((value).type == VAL_OBJ)

#define AS_BOOL(value)  ((value).as.Bool)
#define AS_FLOAT(value) ((value).as.Float)
#define AS_INT(value)   ((value).as.Int)
#define AS_OBJ(value) ((value).as.Obj)

#define NIL_VAL              ((value_t) {VAL_NIL,   {.Int = 0}})
#define BOOL_VAL(value)      ((value_t) {VAL_BOOL,  {.Bool = value}})
#define FLOAT_VAL(value)     ((value_t) {VAL_FLOAT, {.Float = value}})
#define INT_VAL(value)       ((value_t) {VAL_INT,   {.Int = value}})
#define OBJ_VAL(object)      ((value_t) {VAL_OBJ, {.Obj = (obj_t *)object}})

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
