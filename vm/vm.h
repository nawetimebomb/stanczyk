#ifndef NLISP_VM_H
#define NLISP_VM_H

#include "chunk.h"
#include "table.h"
#include "value.h"

#define STACK_MAX 256

typedef struct {
    chunk_t *chunk;
    uint8_t *ip;
    value_t stack[STACK_MAX];
    value_t *stack_top;
    table_t symbols; // These are global variables
    table_t strings; // and these, strings stored in memory.
    obj_t *objects;
} VM_t;

typedef enum {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR
} interpret_result_t;

void init_VM();
void free_VM();
void push(value_t value);
value_t pop();
interpret_result_t interpret(const char *source);

#endif
