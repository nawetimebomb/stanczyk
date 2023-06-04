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
#ifndef STANCZYK_CHUNK_H
#define STANCZYK_CHUNK_H

#include "stanczyk.h"
#include "constant.h"

typedef enum {
    // Constants
    OP_PUSH_INT,
    OP_PUSH_FLOAT,
    OP_PUSH_HEX,
    OP_PUSH_STR,
    OP_PUSH_PTR,

    // Keywords
    OP_JUMP,
    OP_JUMP_IF_FALSE,
    OP_LOOP,

    // Intrinsics
    OP_ADD,
    OP_AND,
    OP_CALL_CFUNC,
    OP_DEC,
    OP_DEFINE_PTR,
    OP_DIVIDE,
    OP_DROP,
    OP_DUP,
    OP_EQUAL,
    OP_GREATER,
    OP_GREATER_EQUAL,
    OP_INC,
    OP_LESS,
    OP_LESS_EQUAL,
    OP_LOAD8,
    OP_MULTIPLY,
    OP_NOT_EQUAL,
    OP_OR,
    OP_OVER,
    OP_PRINT,
    OP_RETURN,
    OP_SAVE8,
    OP_SUBSTRACT,
    OP_SWAP,
    OP_SYS0,
    OP_SYS1,
    OP_SYS2,
    OP_SYS3,
    OP_SYS4,
    OP_SYS5,
    OP_SYS6,
    OP_TAKE,

    OP_CALL,
    OP_DEFINE_FUNCTION,
    OP_FUNCTION_END,

    // Special
    OP_END,
    OP_EOC
} Op;

typedef struct {
    int start;
    int count;
    int capacity;
    bool erred;
    u8 *code;
    int *lines;
    ConstantArray constants;
} Chunk;

void init_chunk(Chunk *);
int add_constant(Chunk *, Value);
void write_chunk(Chunk *, u8, int);
void free_chunk(Chunk *);

#endif
