#include <stdio.h>

#include "memory.h"
#include "value.h"

void init_value_array(value_array_t *array) {
    array->capacity = 0;
    array->count = 0;
    array->values = NULL;
}

void write_value_array(value_array_t *array, value_t value) {
    if (array->capacity < array->count + 1) {
        int prev_capacity = array->capacity;
        array->capacity = GROW_CAPACITY(prev_capacity);
        array->values = GROW_ARRAY(value_t, array->values, prev_capacity, array->capacity);
    }

    array->values[array->count] = value;
    array->count++;
}

void free_value_array(value_array_t *array) {
    FREE_ARRAY(value_t, array->values, array->capacity);
    init_value_array(array);
}

bool values_equal(value_t a, value_t b) {
    if (a.type != b.type) return false;

    switch (a.type) {
        case VAL_BOOL:   return AS_BOOL(a) == AS_BOOL(b);
        case VAL_NIL:    return true;
        case VAL_NUMBER: return AS_NUMBER(a) == AS_NUMBER(b);
        default:         return false;
    }
}

void print_value(value_t value) {
    switch (value.type) {
        case VAL_BOOL: printf(AS_BOOL(value) ? "true" : "false"); break;
        case VAL_NIL: printf("nil"); break;
        case VAL_NUMBER: printf("%g", AS_NUMBER(value)); break;
    }
}
