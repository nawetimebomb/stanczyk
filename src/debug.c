#include <stdio.h>
// TODO: remove when moved to printer file
#include <string.h>

#include "chunk.h"
#include "debug.h"
#include "value.h"

// TODO: Move to a printer file
static void print_center_text(const char *s) {
    int position = strlen(s) / 2;
    printf(STYLE_BOLD"===%*s%*s===\n"STYLE_OFF, 10 + position, s, 10 - position, "");
}

void disassemble_chunk(chunk_t *chunk, const char *name) {
    print_center_text(name);

    for (int offset = 0; offset < chunk->count;) {
        offset = disassemble_instruction(chunk, offset);
    }
}

static int constant_instruction(const char *name, chunk_t *chunk, int offset) {
    uint8_t constant = chunk->code[offset + 1];
    printf("%-16s %4d '", name, constant);
    print_value(chunk->constants.values[constant]);
    printf("'\n");
    return offset + 2;
}

static int simple_instruction(const char *name, int offset) {
    printf("%s\n", name);
    return offset + 1;
}

static int byte_instruction(const char *name, chunk_t *chunk, int offset) {
    uint8_t slot = chunk->code[offset + 1];
    printf("%-16s %d\n", name, slot);
    return offset + 2;
}

static int jump_instruction(const char *name, int sign, chunk_t *chunk, int offset) {
    uint16_t jump = (uint16_t)(chunk->code[offset + 1] << 8);
    jump |= chunk->code[offset + 2];
    printf("%-16s %4d -> %d\n", name, offset, offset + 3 + sign * jump);
    return offset + 3;
}

int disassemble_instruction(chunk_t *chunk, int offset) {
    printf("%04d ", offset);
    if (offset > 0 && chunk->lines[offset] == chunk->lines[offset - 1]) {
        printf("   | ");
    } else {
        printf("%4d ", chunk->lines[offset]);
    }

    uint8_t instruction = chunk->code[offset];

    switch (instruction) {
        case OP_CONSTANT:
            return constant_instruction("OP_CONSTANT", chunk, offset);
        case OP_LIST_CREATE:
            return byte_instruction("OP_LIST_CREATE", chunk, offset);
        case OP_LIST_GET_INDEX:
            return constant_instruction("OP_LIST_GET_INDEX", chunk, offset);
        case OP_LIST_STORE_INDEX:
            return constant_instruction("OP_LIST_STORE_INDEX", chunk, offset);
        case OP_NIL:
            return simple_instruction("OP_NIL", offset);
        case OP_TRUE:
            return simple_instruction("OP_TRUE", offset);
        case OP_FALSE:
            return simple_instruction("OP_FALSE", offset);
        case OP_GET_LOCAL:
            return byte_instruction("OP_GET_LOCAL", chunk, offset);
        case OP_SET_LOCAL:
            return byte_instruction("OP_SET_LOCAL", chunk, offset);
        case OP_GET_GLOBAL:
            return constant_instruction("OP_GET_GLOBAL", chunk, offset);
        case OP_DEFINE_GLOBAL:
            return constant_instruction("OP_DEFINE_GLOBAL", chunk, offset);
        case OP_SET_GLOBAL:
            return constant_instruction("OP_SET_GLOBAL", chunk, offset);
        case OP_EQUAL:
            return simple_instruction("OP_EQUAL", offset);
        case OP_GREATER:
            return simple_instruction("OP_GREATER", offset);
        case OP_LESS:
            return simple_instruction("OP_LESS", offset);
        case OP_AND:
            return simple_instruction("OP_AND", offset);
        case OP_OR:
            return simple_instruction("OP_OR", offset);
        case OP_ADD:
            return simple_instruction("OP_ADD", offset);
        case OP_SUBTRACT:
            return simple_instruction("OP_SUBTRACT", offset);
        case OP_MULTIPLY:
            return simple_instruction("OP_MULTIPLY", offset);
        case OP_DIVIDE:
            return simple_instruction("OP_DIVIDE", offset);
        case OP_NEGATE:
            return simple_instruction("OP_NEGATE", offset);
        case OP_PRINT:
            return simple_instruction("OP_PRINT", offset);
        case OP_DROP:
            return simple_instruction("OP_DROP", offset);
        case OP_DROPN:
            return constant_instruction("OP_DROPN", chunk, offset);
        case OP_DUP:
            return simple_instruction("OP_DUP", offset);
        case OP_JUMP_IF_FALSE:
            return jump_instruction("OP_JUMP_IF_FALSE", 1, chunk, offset);
        case OP_JUMP:
            return jump_instruction("OP_JUMP", 1, chunk, offset);
        case OP_QUIT:
            return jump_instruction("OP_QUIT", 1, chunk, offset);
        case OP_LOOP:
            return jump_instruction("OP_LOOP", -1, chunk, offset);
        case OP_CALL:
            return byte_instruction("OP_CALL", chunk, offset);
        case OP_SPLIT:
            return simple_instruction("OP_SPLIT", offset);
        case OP_JOIN:
            return simple_instruction("OP_JOIN", offset);
        case OP_CAST:
            return simple_instruction("OP_CAST", offset);
        case OP_RETURN:
            return simple_instruction("OP_RETURN", offset);
        default:
            printf("Error: Unknown op %d\n", instruction);
            return offset + 1;
    }
}
