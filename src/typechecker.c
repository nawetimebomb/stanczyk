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
#include <stdlib.h>

#include "typechecker.h"
#include "chunk.h"
#include "constant.h"
#include "object.h"
#include "debug.h"

#define STACK_MAX 10

typedef struct {
    Chunk *chunk;
    u8 *ip;
    DataType stack[STACK_MAX];
    DataType *stack_top;
} Typechecker;

Typechecker typechecker;

static void reset_stack() {
    typechecker.stack_top = typechecker.stack;
}

static void init_typechecker() {
    reset_stack();
}

DataType pop() {
  typechecker.stack_top--;
  return *typechecker.stack_top;
}

static void push(DataType type) {
    *typechecker.stack_top = type;
    typechecker.stack_top++;
}

static char *get_data_type_str(DataType type) {
    switch (type) {
        case DATA_BOOL:  return "Bool";
        case DATA_FLOAT: return "Float";
        case DATA_HEX:   return "Hex";
        case DATA_INT:   return "Int";
        case DATA_NULL:  return "null";
        case DATA_PTR:   return "Ptr";
        case DATA_STR:   return "Str";
    }

    return "Unhandled";
}

static int run() {
#define READ_BYTE() (*typechecker.ip++)
#define READ_CONSTANT() (typechecker.chunk->constants.values[READ_BYTE()])
#define READ_STRING() AS_STRING(READ_CONSTANT())
#define READ_SHORT() (typechecker.ip += 2, (u16)((typechecker.ip[-2] << 8) | typechecker.ip[-1]))
    int stack_count = 0;
    bool block_check = false;
    int block_count = 0;
    for (;;) {
#ifdef DEBUG_BYTECODE
        printf("          ");
        for (DataType* slot = typechecker.stack; slot < typechecker.stack_top; slot++) {
            printf("[ ");
            printf("%s", get_data_type_str(*slot));
            printf(" ]");
        }
        printf("\n");
        disassemble_instruction(typechecker.chunk, (int)(typechecker.ip - typechecker.chunk->code));
#endif

        u8 instruction;
        switch (instruction = READ_BYTE()) {
            case OP_PUSH_INT: {
                typechecker.ip++;
                push(DATA_INT);
                stack_count++;
            } break;
            case OP_PUSH_STR: {
                typechecker.ip++;
                push(DATA_INT);
                push(DATA_STR);
                stack_count += 2;
            } break;
            case OP_PUSH_FLOAT: {
                typechecker.ip++;
                push(DATA_FLOAT);
                stack_count++;
            } break;
            case OP_PUSH_PTR: {
                typechecker.ip++;
                push(DATA_PTR);
                stack_count++;
            } break;
            case OP_PUSH_HEX: {
                typechecker.ip++;
                push(DATA_HEX);
                stack_count++;
            } break;
            case OP_DEFINE_PTR: {
                Value a = READ_CONSTANT();
                Value b = READ_CONSTANT();

                if (!IS_STRING(a) && !IS_INT(b)) {
                    printf("ERROR: constant types are incorrect\n");
                    exit(1);
                }
            } break;
            case OP_ADD:
            case OP_SUBSTRACT: {
                if (stack_count < 2) {
                    printf("ERROR: Not enough arguments to do arithmetic operation\n");
                    exit(1);
                }
                DataType a = pop();
                DataType b = pop();
                if ((a != DATA_INT && a != DATA_PTR) || (b != DATA_INT && b != DATA_PTR)) {
                    printf("ERROR: arithmetic operations require 2 Int arguments\n"
                           "but got %s and %s\n", get_data_type_str(a), get_data_type_str(b));
                    exit(1);
                }
                stack_count--;
                if (a == DATA_PTR || b == DATA_PTR) {
                    push(DATA_PTR);
                } else {
                    push(DATA_INT);
                }
            } break;
            case OP_MULTIPLY: {
                if (stack_count < 2) {
                    printf("ERROR: Not enough arguments to do arithmetic operation\n");
                    exit(1);
                }
                DataType a = pop();
                DataType b = pop();
                if (a != DATA_INT || b != DATA_INT) {
                    printf("ERROR: arithmetic operations require 2 Int arguments\n"
                           "but got %s and %s\n", get_data_type_str(a), get_data_type_str(b));
                    exit(1);
                }
                stack_count--;
                push(DATA_INT);
            } break;
            case OP_DIVIDE: {
                if (stack_count < 2) {
                    printf("ERROR: Not enough arguments to do arithmetic operation\n");
                    exit(1);
                }
                DataType a = pop();
                DataType b = pop();
                if (a != DATA_INT || b != DATA_INT) {
                    printf("ERROR: arithmetic operations require 2 Int arguments\n"
                           "but got %s and %s\n", get_data_type_str(a), get_data_type_str(b));
                    exit(1);
                }

                push(DATA_INT);
                push(DATA_INT);
            } break;
            case OP_EQUAL:
            case OP_NOT_EQUAL:
            case OP_GREATER:
            case OP_GREATER_EQUAL:
            case OP_LESS:
            case OP_LESS_EQUAL: {
                if (stack_count < 2) {
                    printf("ERROR: Not enough arguments to do order operation\n");
                    exit(1);
                }
                DataType a = pop();
                DataType b = pop();
                if ((a != DATA_INT && a != DATA_BOOL) ||
                    (b != DATA_BOOL && b != DATA_INT && b != DATA_PTR)) {
                    printf("ERROR: comparison operations require 2 Int arguments\n"
                           "but got %s and %s\n", get_data_type_str(b), get_data_type_str(a));
                    exit(1);
                }
                stack_count--;
                push(DATA_BOOL);
            } break;
            case OP_JUMP_IF_FALSE: {
                typechecker.ip += 2;

                if (stack_count < 1) {
                    printf("ERROR: Not enough arguments to do control flow\n");
                    exit(1);
                }

                DataType a = pop();
                if (a != DATA_BOOL) {
                    printf("ERROR: control flow operations requires 1 Bool arguments\n"
                           "but got %s\n", get_data_type_str(a));
                    exit(1);
                }

                stack_count--;

                block_count = stack_count;
                block_check = true;
            } break;
            case OP_LOAD8: {
                if (stack_count < 1) {
                    printf("ERROR: Not enough arguments to do load\n");
                    exit(1);
                }
                pop();
                // TODO: Should be data char*
                push(DATA_PTR);
            } break;
            case OP_CALL: {
                typechecker.ip++;
            } break;
            case OP_DEFINE_FUNCTION: {
                typechecker.ip++;
            } break;
            case OP_FUNCTION_END: {
                typechecker.ip++;
            } break;
            case OP_RETURN: {

            } break;
            case OP_CALL_CFUNC: {
                CFunction *fn = AS_CFUNCTION(READ_CONSTANT());

                if (stack_count < fn->arity - 1) {
                    printf("ERROR: Not enough arguments to call %s\n", fn->name->chars);
                    exit(1);
                }

                for (int i = fn->arity - 1; i >= 0; i--) {
                    DataType test = pop();
                    if (test != fn->arguments[i]) {
                        printf("ERROR: argument %d is a different type\n"
                               "Expected %s, but got %s\n", i + 1,
                               get_data_type_str(fn->arguments[i]), get_data_type_str(test));
                        exit(1);
                    }
                    stack_count--;
                }

                if (fn->ret != DATA_NULL) {
                    stack_count++;
                    push(fn->ret);
                }
            } break;
            case OP_INC:
            case OP_DEC: {
                if (stack_count < 1) {
                    printf("ERROR: Not enough arguments to do increase or decrease operation\n");
                    exit(1);
                }
                DataType a = pop();
                if (a != DATA_INT) {
                    printf("ERROR: decrementing operations requires 1 Int arguments\n"
                           "but got %s\n", get_data_type_str(a));
                }
                push(DATA_INT);
            } break;
            case OP_JUMP: {
                typechecker.ip += 2;

                if (block_check && stack_count != block_count) {
                    printf("ERROR: control flow operations cannot make stack size modifications\n");
                    exit(1);
                }

                block_check = false;
            } break;
            case OP_LOOP: {
                typechecker.ip += 2;
            } break;
            case OP_DUP: {
                if (stack_count < 1) {
                    printf("ERROR: Not enough arguments for 'dup'\n");
                    exit(1);
                }
                DataType a = pop();
                push(a);
                push(a);
                stack_count++;
            } break;
            case OP_OVER: {
                if (stack_count < 2) {
                    printf("ERROR: Not enough arguments for 'over'\n");
                    exit(1);
                }
                DataType a = pop();
                DataType b = pop();
                push(b);
                push(a);
                push(b);
                stack_count++;
            } break;
            case OP_DROP: {
                if (stack_count < 1) {
                    printf("ERROR: Not enough arguments to drop\n");
                    exit(1);
                }
                pop();
                stack_count--;
            } break;
            case OP_SWAP: {
                DataType a = pop();
                DataType b = pop();
                push(a);
                push(b);
            } break;
            case OP_PRINT: {
                if (stack_count < 1) {
                    printf("ERROR: Not enough arguments to print\n");
                    exit(1);
                }
                DataType a = pop();
                if (a != DATA_INT && a != DATA_BOOL) {
                    printf("ERROR: print operation requires an Int argument but got %s\n",
                           get_data_type_str(a));
                    exit(1);
                }
                stack_count--;
            } break;
            case OP_TAKE: {
                if (stack_count < 1) {
                    printf("ERROR: Not enough arguments to take\n");
                    exit(1);
                }
                DataType a = pop();
                push(a);
            } break;
            case OP_SYS1: {
                if (stack_count < 2) {
                    printf("ERROR: insufficient arguments in order to make system call.\n"
                           "Expected 4, got %d\n", stack_count);
                    exit(1);
                }
                pop(); pop();
                stack_count -= 2;
            } break;
            case OP_SYS3: {
                if (stack_count < 4) {
                    printf("ERROR: insufficient arguments in order to make system call.\n"
                           "Expected 4, got %d\n", stack_count);
                    exit(1);
                }
                pop(); pop(); pop(); pop();
                stack_count -= 4;
                push(DATA_INT);
                stack_count++;
            } break;
            case OP_END: return stack_count;
            default: printf("Unreachable\n"); break;
        }
    }
#undef READ_BYTE
#undef READ_CONSTANT
#undef READ_STRING
#undef READ_SHORT
}

bool run_typechecker(Chunk chunk) {
    typechecker.chunk = malloc(sizeof(Chunk));
    init_typechecker();
    typechecker.chunk = &chunk;
    typechecker.ip = chunk.code;

    int stack_count = run();

    if (stack_count != 0) {
        printf("ERROR: Unhandled values in the stack\n");

        for (int i = 0; i < stack_count; i++) {
            printf("[ %s ]", get_data_type_str(typechecker.stack[i]));
        }

        printf("\n");

        exit(1);
    }



    return true;
}
