#ifndef NLISP_VM_H
#define NLISP_VM_H

#include "chunk.h"
#include "value.h"

#define STACK_MAX 256

typedef struct {
    chunk_t *chunk;
    uint8_t *ip;
    value_t stack[STACK_MAX];
    value_t *stack_top;
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
