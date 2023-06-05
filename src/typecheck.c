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
#if DEBUG_MODE
#include <stdio.h>
#endif

#include "typecheck.h"
#include "errors.h"
#include "memory.h"
#include "ir_code.h"
#include "logger.h"

#define STACK_MAX 32

#define ASSERT_NUM_OF_ARGUMENTS(given, expected, token)                 \
    if (given < expected)                                               \
        TYPECHECK_ERROR(token, ERROR__TYPECHECK__INSUFFICIENT_ARGUMENTS, expected, given);
// TODO: Should check for multiple types
#define ASSERT_TYPE(given, expected, token)                             \
    if (given != expected)                                              \
        TYPECHECK_ERROR(token, ERROR__TYPECHECK__INCORRECT_TYPE, get_type_name(expected), get_type_name(given));

typedef struct {
    IRCodeChunk *chunk;
    Code *ip;
    DataType stack[STACK_MAX];
    DataType *stack_top;
} Typecheck;

Typecheck *typecheck;

static const char *get_type_name(DataType type) {
    switch (type) {
        case DATA_BOOL:  return "bool";
        case DATA_FLOAT: return "float";
        case DATA_HEX:   return "hex";
        case DATA_INT:   return "int";
        case DATA_NULL:  return "null";
        case DATA_PTR:   return "ptr";
        case DATA_STR:   return "str";
        default: UNREACHABLE_CODE("typecheck.c->get_type_name"); return "Unreachable";
    }
}

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
#ifdef DEBUG_MODE
        printf("          ");
        for (DataType* slot = typecheck->stack; slot < typecheck->stack_top; slot++) {
            printf("[ ");
            printf("%s", get_type_name(*slot));
            printf(" ]");
        }
        printf("\n");
#endif
        Code instruction = NEXT_BYTE();
        Token *token = &instruction.token;

        switch (instruction.type) {
            /*    ___             _            _
             *   / __|___ _ _  __| |_ __ _ _ _| |_ ___
             *  | (__/ _ \ ' \(_-<  _/ _` | ' \  _(_-<
             *   \___\___/_||_/__/\__\__,_|_||_\__/__/
             */
            case OP_PUSH_INT: {
                push(DATA_INT);
                stack_count++;
            } break;
            case OP_PUSH_STR: {
                push(DATA_INT);
                push(DATA_STR);
                stack_count += 2;
            } break;


            /*   ___     _       _         _
             *  |_ _|_ _| |_ _ _(_)_ _  __(_)__ ___
             *   | || ' \  _| '_| | ' \(_-< / _(_-<
             *  |___|_||_\__|_| |_|_||_/__/_\__/__/
             */
            case OP_ADD:
            case OP_SUBSTRACT: {
                ASSERT_NUM_OF_ARGUMENTS(stack_count, 2, token);
                DataType b = pop();
                DataType a = pop();
                ASSERT_TYPE(b, DATA_INT, token);
                ASSERT_TYPE(a, DATA_INT, token);
                push(DATA_INT);
                stack_count--;
            } break;
            case OP_MULTIPLY:
            case OP_DIVIDE:
            case OP_MODULO: {
                ASSERT_NUM_OF_ARGUMENTS(stack_count, 2, token);
                DataType b = pop();
                DataType a = pop();
                ASSERT_TYPE(b, DATA_INT, token);
                ASSERT_TYPE(a, DATA_INT, token);
                push(DATA_INT);
                stack_count--;
            } break;
            case OP_DROP: {
                ASSERT_NUM_OF_ARGUMENTS(stack_count, 1, token);
                pop();
                stack_count--;
            } break;
            case OP_PRINT: {
                ASSERT_NUM_OF_ARGUMENTS(stack_count, 1, token);
                DataType a = pop();
                ASSERT_TYPE(a, DATA_INT, token);
                stack_count--;
            } break;
            case OP_SYSCALL3: {
                ASSERT_NUM_OF_ARGUMENTS(stack_count, 4, token);
                pop(); pop(); pop(); pop();
                push(DATA_INT);
                stack_count -= 3;
            } break;

            /*   _  __                           _
             *  | |/ /___ _  ___ __ _____ _ _ __| |___
             *  | ' </ -_) || \ V  V / _ \ '_/ _` (_-<
             *  |_|\_\___|\_, |\_/\_/\___/_| \__,_/__/
             *            |__/
             */
            case OP_EOC: {
                return stack_count;
            } break;
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
