#include <stdio.h>
#include <stdarg.h>

#include "chunk.h"
#include "common.h"
#include "compiler.h"
#include "debug.h"
#include "vm.h"

VM_t VM;

static void reset_stack() {
    VM.stack_top = VM.stack;
}

static void runtime_error(const char *format, ...) {
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
    fputs("\n", stderr);

    size_t instruction = VM.ip - VM.chunk->code - 1;
    int line = VM.chunk->lines[instruction];
    fprintf(stderr, "[line %d] in script\n", line);
    reset_stack();
}

static value_t peek(int distance) {
    return VM.stack_top[-1 - distance];
}

static bool is_falsey(value_t value) {
    return IS_NIL(value) || (IS_BOOL(value) && !AS_BOOL(value));
}

void init_VM() {
    reset_stack();
}

void free_VM() {}

static interpret_result_t run() {

#define READ_BYTE() (*VM.ip++)
#define READ_CONSTANT() (VM.chunk->constants.values[READ_BYTE()])
#define BINARY_OP(value_type, op)                           \
    do {                                                    \
        if (!IS_NUMBER(peek(0)) || !IS_NUMBER(peek(1))) {   \
            runtime_error("operands must be numbers.");     \
            return INTERPRET_RUNTIME_ERROR;                 \
        }                                                   \
        double b = AS_NUMBER(pop());                        \
        double a = AS_NUMBER(pop());                        \
        push (value_type(a op b));                          \
    } while (false)

    for (;;) {
#ifdef DEBUG_TRACE_EXECUTION
        printf("          ");
        for (value_t *slot = VM.stack; slot < VM.stack_top; slot++) {
            printf("[ ");
            print_value(*slot);
            printf(" ]");
        }
        printf("\n");
        disassemble_instruction(VM.chunk, (int)(VM.ip - VM.chunk->code));
#endif

        uint8_t instruction;
        switch (instruction = READ_BYTE()) {
            case OP_CONSTANT: {
                value_t constant = READ_CONSTANT();
                push(constant);
                printf("\n");
            } break;
            case OP_NIL:      push(NIL_VAL); break;
            case OP_TRUE:     push(BOOL_VAL(true)); break;
            case OP_FALSE:    push(BOOL_VAL(false)); break;
            case OP_EQUAL: {
                value_t b = pop();
                value_t a = pop();
                push(BOOL_VAL(values_equal(a, b)));
            } break;
            case OP_GREATER:  BINARY_OP(BOOL_VAL, >); break;
            case OP_LESS:     BINARY_OP(BOOL_VAL, <); break;
            case OP_ADD:      BINARY_OP(NUMBER_VAL, +); break;
            case OP_SUBTRACT: BINARY_OP(NUMBER_VAL, -); break;
            case OP_MULTIPLY: BINARY_OP(NUMBER_VAL, *); break;
            case OP_DIVIDE:   BINARY_OP(NUMBER_VAL, /); break;
            case OP_NOT:      push(BOOL_VAL(is_falsey(pop()))); break;
            case OP_NEGATE: {
                if (!IS_NUMBER(peek(0))) {
                    runtime_error("operand must be a number.");
                    return INTERPRET_RUNTIME_ERROR;
                }
                push(NUMBER_VAL(-AS_NUMBER(pop())));
            } break;
            case OP_RETURN: {
                print_value(pop());
                printf("\n");
                return INTERPRET_OK;
            }
        }
    }

#undef READ_BYTE
#undef READ_CONSTANT
#undef BINARY_OP
}

void push(value_t value) {
    *VM.stack_top = value;
    VM.stack_top++;
}

value_t pop() {
    VM.stack_top--;
    return *VM.stack_top;
}

interpret_result_t interpret(const char *source) {
    chunk_t chunk;
    init_chunk(&chunk);

    if (!compile(source, &chunk)) {
        free_chunk(&chunk);
        return INTERPRET_COMPILE_ERROR;
    }

    VM.chunk = &chunk;
    VM.ip = VM.chunk->code;

    interpret_result_t result = run();

    free_chunk(&chunk);
    return result;
}
