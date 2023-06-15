#ifndef STANCZYK_VM_H
#define STANCZYK_VM_H

#include "chunk.h"
#include "common.h"
#include "table.h"
#include "object.h"
#include "value.h"

#define FRAMES_MAX 1024
#define STACK_MAX  (FRAMES_MAX * UINT8_COUNT)

typedef struct {
    procedure_t *procedure;
    uint8_t *ip;
    value_t *slots;
} callframe_t;

typedef struct {
    callframe_t frames[FRAMES_MAX];
    int frame_count;

    value_t stack[STACK_MAX];
    value_t *stack_top;
    table_t symbols; // These are global variables
    table_t strings; // and these, strings stored in memory.
    obj_t *objects;

    size_t bytes_alloc;
    size_t next_gc;

    int gray_count;
    int gray_capacity;
    obj_t **gray_stack;
} VM_t;

typedef enum {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR
} interpret_result_t;

void runtime_throw(const char *format);
void init_VM();
void free_VM();
void push(value_t value);
value_t pop();
interpret_result_t interpret(const char *source);

#endif
