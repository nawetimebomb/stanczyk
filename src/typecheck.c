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
#include "typecheck.h"
#include "errors.h"
#include "memory.h"
#include "ir_code.h"
#include "logger.h"

#define STACK_MAX 32

#define ASSERT_NUM_OF_ARGUMENTS(given, expected, token)                 \
    if (given < expected)                                               \
        TYPECHECK_ERROR(token, ERROR__TYPECHECK__INSUFFICIENT_ARGUMENTS, expected, given);

typedef struct {
    IRCodeChunk *chunk;
    Code *ip;
    DataType stack[STACK_MAX];
    DataType *stack_top;
} Typecheck;

Typecheck *typecheck;

static void reset_stack() {
    typecheck->stack_top = typecheck->stack;
}

static void start_typecheck(IRCodeChunk chunk) {
    typecheck = ALLOCATE(Typecheck);
    typecheck->chunk = ALLOCATE(IRCodeChunk);
    typecheck->chunk = &chunk;
    typecheck->ip = chunk.code;
    reset_stack();
}

static void stop_typecheck() {
    FREE(Typecheck, typecheck);
}

static DataType pop() {
    typecheck->stack_top--;
    return *typecheck->stack_top;
}

static void push(DataType type) {
    *typecheck->stack_top = type;
    typecheck->stack_top++;
}

static int run() {
#define NEXT_BYTE() (*typecheck->ip++)
    int stack_count = 0;

    for (;;) {
        Code instruction = NEXT_BYTE();
        Token *token = &instruction.token;

        switch (instruction.type) {
            case OP_PUSH_INT: {
                push(DATA_INT);
                stack_count++;
            } break;
            case OP_PUSH_STR: {
                push(DATA_INT);
                push(DATA_STR);
                stack_count += 2;
            } break;

            case OP_ADD: {
                ASSERT_NUM_OF_ARGUMENTS(stack_count, 2, token);
                DataType a = pop();
                DataType b = pop();
                push(DATA_INT);
                stack_count--;
            } break;

            case OP_PRINT: {
                ASSERT_NUM_OF_ARGUMENTS(stack_count, 1, token);
                DataType a = pop();
                stack_count--;
            } break;

            case OP_EOC: {
                return stack_count;
            } break;
            default: UNREACHABLE_CODE("typecheck.c->run"); break;
        }
    }
#undef NEXT_BYTE
}

void typecheck_run(IRCodeChunk *chunk) {
    start_typecheck(*chunk);

    int stack_result = run();

    if (stack_result != 0) {
        // TODO: Improve the following error
        TYPECHECK_ERROR(NULL, "Unhandled values on the stack");
    }

    stop_typecheck();
}
