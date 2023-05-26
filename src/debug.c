/* The Stańczyk Programming Language
 *
 *            ¿«fº"└└-.`└└*∞▄_              ╓▄∞╙╙└└└╙╙*▄▄
 *         J^. ,▄▄▄▄▄▄_      └▀████▄ç    JA▀            └▀v
 *       ,┘ ▄████████████▄¿     ▀██████▄▀└      ╓▄██████▄¿ "▄_
 *      ,─╓██▀└└└╙▀█████████      ▀████╘      ▄████████████_`██▄
 *     ;"▄█└      ,██████████-     ▐█▀      ▄███████▀▀J█████▄▐▀██▄
 *     ▌█▀      _▄█▀▀█████████      █      ▄██████▌▄▀╙     ▀█▐▄,▀██▄
 *    ▐▄▀     A└-▀▌  █████████      ║     J███████▀         ▐▌▌╙█µ▀█▄
 *  A╙└▀█∩   [    █  █████████      ▌     ███████H          J██ç ▀▄╙█_
 * █    ▐▌    ▀▄▄▀  J█████████      H    ████████          █    █  ▀▄▌
 *  ▀▄▄█▀.          █████████▌           ████████          █ç__▄▀ ╓▀└ ╙%_
 *                 ▐█████████      ▐    J████████▌          .└╙   █¿   ,▌
 *                 █████████▀╙╙█▌└▐█╙└██▀▀████████                 ╙▀▀▀▀
 *                ▐██▀┘Å▀▄A └▓█╓▐█▄▄██▄J▀@└▐▄Å▌▀██▌
 *                █▄▌▄█M╨╙└└-           .└└▀**▀█▄,▌
 *                ²▀█▄▄L_                  _J▄▄▄█▀└
 *                     └╙▀▀▀▀▀MMMR████▀▀▀▀▀▀▀└
 *
 *
 * ███████╗████████╗ █████╗ ███╗   ██╗ ██████╗███████╗██╗   ██╗██╗  ██╗
 * ██╔════╝╚══██╔══╝██╔══██╗████╗  ██║██╔════╝╚══███╔╝╚██╗ ██╔╝██║ ██╔╝
 * ███████╗   ██║   ███████║██╔██╗ ██║██║       ███╔╝  ╚████╔╝ █████╔╝
 * ╚════██║   ██║   ██╔══██║██║╚██╗██║██║      ███╔╝    ╚██╔╝  ██╔═██╗
 * ███████║   ██║   ██║  ██║██║ ╚████║╚██████╗███████╗   ██║   ██║  ██╗
 * ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝
 */
#include <stdio.h>

#include "debug.h"
#include "constant.h"

void disassemble_chunk(Chunk *chunk, const char *name) {
    printf("== %s ==\n", name);
    for (int offset = 0; offset < chunk->count;) {
        offset = disassemble_instruction(chunk, offset);
    }
}

static int simple_instruction(const char *name, int offset) {
    printf("%s\n", name);
    return offset + 1;
}

static int constant_instruction(const char *name, Chunk *chunk, int offset) {
    u8 constant = chunk->code[offset + 1];
    printf("%-16s %4d '", name, constant);
    print_constant(chunk->constants.values[constant]);
    printf("'\n");
    return offset + 2;
}

static int jump_instruction(const char *name, int sign, Chunk *chunk, int offset) {
    u16 jump = (u16)(chunk->code[offset + 1] << 8);
    jump |= chunk->code[offset + 2];
    printf("%-16s %4d -> %d\n", name, offset, offset + 3 + sign * jump);
    return offset + 3;
}

int disassemble_instruction(Chunk *chunk, int offset) {
    printf("IP %08d ", offset);
    if (offset > 0 && chunk->lines[offset] == chunk->lines[offset - 1]) {
        printf("   | ");
    } else {
        printf("%4d ", chunk->lines[offset]);
    }

    u8 instruction = chunk->code[offset];
    switch (instruction) {
        // Constants
        case OP_PUSH_INT:
            return constant_instruction("OP_PUSH_INT", chunk, offset);
        case OP_PUSH_STR:
            return constant_instruction("OP_PUSH_STR", chunk, offset);
        // Keywords
        case OP_JUMP:
            return jump_instruction("OP_JUMP", 1, chunk, offset);
        case OP_JUMP_IF_FALSE:
            return jump_instruction("OP_JUMP_IF_FALSE", 1, chunk, offset);
        case OP_LOOP:
            return jump_instruction("OP_LOOP", -1, chunk, offset);
        case OP_MEMORY:
            return simple_instruction("OP_MEMORY", offset);
        // Intrinsics
        case OP_ADD:
            return simple_instruction("OP_ADD", offset);
        case OP_AND:
            return simple_instruction("OP_AND", offset);
        case OP_DEC:
            return simple_instruction("OP_DEC", offset);
        case OP_DIVIDE:
            return simple_instruction("OP_DIVIDE", offset);
        case OP_DROP:
            return simple_instruction("OP_DROP", offset);
        case OP_DUP:
            return simple_instruction("OP_DUP", offset);
        case OP_EQUAL:
            return simple_instruction("OP_EQUAL", offset);
        case OP_GREATER:
            return simple_instruction("OP_GREATER", offset);
        case OP_GREATER_EQUAL:
            return simple_instruction("OP_GREATER_EQUAL", offset);
        case OP_INC:
            return simple_instruction("OP_INC", offset);
        case OP_LESS:
            return simple_instruction("OP_LESS", offset);
        case OP_LESS_EQUAL:
            return simple_instruction("OP_LESS_EQUAL", offset);
        case OP_LOAD8:
            return simple_instruction("OP_LOAD8", offset);
        case OP_MULTIPLY:
            return simple_instruction("OP_MULTIPLY", offset);
        case OP_NOT_EQUAL:
            return simple_instruction("OP_NOT_EQUAL", offset);
        case OP_OR:
            return simple_instruction("OP_OR", offset);
        case OP_OVER:
            return simple_instruction("OP_OVER", offset);
        case OP_PRINT:
            return simple_instruction("OP_PRINT", offset);
        case OP_RETURN:
            return simple_instruction("OP_RETURN", offset);
        case OP_SAVE8:
            return simple_instruction("OP_SAVE8", offset);
        case OP_SUBSTRACT:
            return simple_instruction("OP_SUBSTRACT", offset);
        case OP_SYS4:
            return simple_instruction("OP_SYS4", offset);
        case OP_SWAP:
            return simple_instruction("OP_SWAP", offset);
        // Special
        case OP_END:
            return simple_instruction("OP_END", offset);
        default:
            printf("Unknown OP %d\n", instruction);
            return offset + 1;
    }
}
