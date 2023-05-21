#ifndef NLISP_CHUNK_H
#define NLISP_CHUNK_H

#include "common.h"
#include "value.h"

typedef enum {
    OP_CONSTANT,
    OP_LIST_CREATE,
    OP_LIST_GET_INDEX,
    OP_LIST_STORE_INDEX,
    OP_NIL,
    OP_TRUE,
    OP_FALSE,
    OP_GET_LOCAL,
    OP_SET_LOCAL,
    OP_GET_GLOBAL,
    OP_DEFINE_GLOBAL,
    OP_SET_GLOBAL,
    OP_EQUAL,
    OP_GREATER,
    OP_LESS,
    OP_AND,
    OP_OR,
    OP_ADD,
    OP_SUBTRACT,
    OP_MULTIPLY,
    OP_DIVIDE,
    OP_NEGATE,
    OP_PRINT,
    OP_DROP,
    OP_DROPN,
    OP_DUP,
    OP_JUMP_IF_FALSE,
    OP_JUMP,
    OP_QUIT,
    OP_LOOP,
    OP_CALL,
    OP_SPLIT,
    OP_JOIN,
    OP_CAST,
    OP_RETURN
} op_code_t;

typedef struct {
    int count;
    int capacity;
    uint8_t* code;
    int *lines;
    value_array_t constants;
} chunk_t;

void init_chunk(chunk_t *chunk);
void write_chunk(chunk_t *chunk, uint8_t byte, int line);
int add_constant(chunk_t *chunk, value_t value);
void free_chunk(chunk_t *chunk);

#endif
