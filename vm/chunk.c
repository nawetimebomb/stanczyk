#include <stdlib.h>

#include "chunk.h"
#include "memory.h"
#include "value.h"

void init_chunk(chunk_t *chunk) {
    chunk->count = 0;
    chunk->capacity = 0;
    chunk->code = NULL;
    chunk->lines = NULL;
    init_value_array(&chunk->constants);
}

void write_chunk(chunk_t *chunk, uint8_t byte, int line) {
    if (chunk->capacity < chunk->count + 1) {
        int prev_capacity = chunk->capacity;
        chunk->capacity = GROW_CAPACITY(prev_capacity);
        chunk->code = GROW_ARRAY(uint8_t, chunk->code, prev_capacity, chunk->capacity);
        chunk->lines = GROW_ARRAY(int, chunk->lines, prev_capacity, chunk->capacity);
    }

    chunk->code[chunk->count] = byte;
    chunk->lines[chunk->count] = line;
    chunk->count++;
}

int add_constant(chunk_t *chunk, value_t value) {
    write_value_array(&chunk->constants, value);
    return chunk->constants.count - 1;
}

void free_chunk(chunk_t *chunk) {
    FREE_ARRAY(uint8_t, chunk->code, chunk->capacity);
    FREE_ARRAY(int, chunk->lines, chunk->capacity);
    free_value_array(&chunk->constants);
    init_chunk(chunk);
}
