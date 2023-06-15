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
        case DATA_INT:   return "int";
        case DATA_NULL:  return "null";
        case DATA_PTR:   return "ptr";
        default: UNREACHABLE_CODE("typecheck.c->get_type_name"); return "Unreachable";
    }
}

static void ASSERT_NUM_OF_ARGUMENTS(int given, int expected, Token *token) {
    if (given < expected) {
        TYPECHECK_ERROR(token, ERROR__TYPECHECK__INSUFFICIENT_ARGUMENTS, expected, given);
    }
}

static void ASSERT_TYPE(DataType given, DataType expected[], int ecount, Token *token) {
    bool allowed = false;

    for (int i = 0; i < ecount; i++) {
        if (given == expected[i]) {
            allowed = true;
        }
    }

    if (!allowed) {
        // TODO: It should show all "expected" values
        TYPECHECK_ERROR(token, ERROR__TYPECHECK__INCORRECT_TYPE,
                        get_type_name(expected[0]),
                        get_type_name(given));
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
                push(DATA_PTR);
                stack_count += 2;
            } break;


            /*   ___     _       _         _
             *  |_ _|_ _| |_ _ _(_)_ _  __(_)__ ___
             *   | || ' \  _| '_| | ' \(_-< / _(_-<
             *  |___|_||_\__|_| |_|_||_/__/_\__/__/
             */
            case OP_CAST: {
                DataType dtype = AS_DTYPE(instruction.operand);
                ASSERT_NUM_OF_ARGUMENTS(stack_count, 1, token);
                pop();
                push(dtype);
            } break;
            case OP_ADD:
            case OP_SUBSTRACT: {
                ASSERT_NUM_OF_ARGUMENTS(stack_count, 2, token);
                DataType b = pop();
                DataType a = pop();
                DataType expected[1] = {DATA_INT};
                ASSERT_TYPE(b, expected, 1, token);
                ASSERT_TYPE(a, expected, 1, token);
                push(DATA_INT);
                stack_count--;
            } break;
            case OP_MULTIPLY:
            case OP_DIVIDE:
            case OP_MODULO: {
                ASSERT_NUM_OF_ARGUMENTS(stack_count, 2, token);
                DataType b = pop();
                DataType a = pop();
                DataType expected[1] = {DATA_INT};
                ASSERT_TYPE(b, expected, 1, token);
                ASSERT_TYPE(a, expected, 1, token);
                push(DATA_INT);
                stack_count--;
            } break;
            case OP_EQUAL:
            case OP_NOT_EQUAL:
            case OP_LESS:
            case OP_LESS_EQUAL:
            case OP_GREATER:
            case OP_GREATER_EQUAL: {
                ASSERT_NUM_OF_ARGUMENTS(stack_count, 2, token);
                DataType b = pop();
                DataType a = pop();
                DataType expected[1] = {DATA_INT};
                ASSERT_TYPE(b, expected, 1, token);
                ASSERT_TYPE(a, expected, 1, token);
                push(DATA_BOOL);
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
                DataType expected[2] = {DATA_INT, DATA_BOOL};
                ASSERT_TYPE(a, expected, 2, token);
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
