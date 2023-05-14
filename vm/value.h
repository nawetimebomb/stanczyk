#ifndef NLISP_VALUE_H
#define NLISP_VALUE_H

#include "common.h"

typedef enum {
    VAL_BOOL,
    VAL_NIL,
    VAL_NUMBER
} value_type_t;

typedef struct {
    value_type_t type;
    union {
        bool boolean;
        double number;
    } as;
} value_t;

#define IS_BOOL(value)   ((value).type == VAL_BOOL)
#define IS_NIL(value)    ((value).type == VAL_NIL)
#define IS_NUMBER(value) ((value).type == VAL_NUMBER)

#define AS_BOOL(value)   ((value).as.boolean)
#define AS_NUMBER(value) ((value).as.number)

#define BOOL_VAL(value)   ((value_t){VAL_BOOL, {.boolean = value}})
#define NIL_VAL           ((value_t){VAL_NIL, {.number = 0}})
#define NUMBER_VAL(value) ((value_t){VAL_NUMBER, {.number = value}})

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
