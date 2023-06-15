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
#include <string.h>

#include "chunk.h"
#include "ir_code.h"
#include "compiler.h"
#include "object.h"
#include "debug.h"

#define READ_BYTE() (*writer->ip++)
#define READ_CONSTANT() (writer->chunk->constants.values[READ_BYTE()])
#define READ_STRING() AS_STRING(READ_CONSTANT())
#define READ_SHORT() (writer->ip += 2, (u16)((writer->ip[-2] << 8) | writer->ip[-1]))

CompilerResult generate_x64_linux(Writer *writer) {
    OutputArray *code = &writer->code;
    OutputArray *strs = &writer->strs;
    OutputArray *mems = &writer->mems;
    OutputArray *flts = &writer->flts;
    for (;;) {
#ifdef DEBUG_BYTECODE
        disassemble_instruction(writer->chunk, (int)(writer->ip - writer->chunk->code));
#endif

        u8 instruction;
        int offset = writer->ip - writer->chunk->code;
        if (offset > 0 &&
            writer->chunk->lines[offset] == writer->chunk->lines[offset - 1]) {
        } else {
            append(code, "/*    line %d    */", writer->chunk->lines[offset]);
        }
        append(code, "ip_%d:", offset);
        switch (instruction = READ_BYTE()) {
            // Constants
            case OP_PUSH_INT: {
                int value = AS_INT(READ_CONSTANT());
                append(code, "    /*    %d    */", value);
                append(code, "    mov    $%d, rax", value);
                append(code, "    push   rax");
            } break;
            case OP_PUSH_STR: {
                String *value = READ_STRING();
                append(code, "    /*    len: %d str: str_%d    */",
                       value->length, strs->count);
                append(code, "    mov    $%d, rax", value->length);
                append(code, "    push   rax");
                append(code, "    lea    str_%d(rip), rax", strs->count);
                append(code, "    push   rax");
                append(strs, "%s", value->chars);
            } break;
            case OP_PUSH_FLOAT: {
                float value = AS_FLOAT(READ_CONSTANT());
                append(code, "    /*    %f    */", value);
                append(code, "    movss  float_%d(rip), xmm0", flts->count);
                append(flts, "float_%d: .single %f\n", flts->count, value);
            } break;
            case OP_PUSH_HEX: {
                const char *hex = READ_STRING()->chars;
                append(code, "    /*    %s    */", hex);
                append(code, "    mov    $%s, rax", hex);
                append(code, "    push   rax");
            } break;
            case OP_PUSH_PTR: {
                const char *name = READ_STRING()->chars;
                append(code, "    /*    memory: %s    */", name);
                append(code, "    lea    %s(rip), rax", name);
                append(code, "    push   rax");
            } break;
            // Keywords
            case OP_JUMP: {
                u16 offset = READ_SHORT();
                int result_ip = (writer->ip - writer->chunk->code) + offset;
                append(code, "    /*    else (ip_%d)    */", result_ip);
                append(code, "    jmp    ip_%d", result_ip);
            } break;
            case OP_JUMP_IF_FALSE: {
                u16 offset = READ_SHORT();
                int result_ip = (writer->ip - writer->chunk->code) + offset;
                append(code, "    /*    do (ip_%d)    */", result_ip);
                append(code, "    pop    rax");
                append(code, "    test   rax, rax");
                append(code, "    jz     ip_%d", result_ip);
            } break;
            case OP_LOOP: {
                u16 offset = READ_SHORT();
                int result_ip = (writer->ip - writer->chunk->code) - offset;
                append(code, "    /*    loop (ip_%d)    */", result_ip);
                append(code, "    jmp    ip_%d", result_ip);
            } break;
            // Intrinsics
            case OP_ADD: {
                append(code, "    /*    __SYS_ADD    */");
                append(code, "    pop    rax");
                append(code, "    pop    rbx");
                append(code, "    add    rbx, rax");
                append(code, "    push   rax");
            } break;
            case OP_AND: {
                printf("Not implemented\n");
                return COMPILER_GENERATOR_ERROR;
            } break;
            case OP_CALL_CFUNC: {
                CFunction * fn = AS_CFUNCTION(READ_CONSTANT());
                char *regs[6] = { "rdi", "rsi", "rdx", "rcx", "r8", "r9" };

                append(code, "    /*    %s    */", fn->name->chars);

                for (int i = fn->arity - 1; i >= 0; i--) {
                    DataType reg = fn->arguments[i];
                    if (reg != DATA_FLOAT) {
                        append(code, "    pop    %s", regs[i]);
                    }
                }

                append(code, "    call   %s", fn->cname->chars);

                if (fn->ret != DATA_NULL) {
                    append(code, "    push   rax");
                }
            } break;
            case OP_DEC: {
                append(code, "    /*    dec    */");
                append(code, "    pop    rax");
                append(code, "    dec    rax");
                append(code, "    push   rax");
            } break;
            case OP_DEFINE_FUNCTION: {
                Function *fn = AS_FUNCTION(READ_CONSTANT());
                if (fn->called) {
                    append(code, "    /* define: %s    */", fn->name->chars);
                    append(code, "    jmp    %s_end", fn->name->chars);
                    append(code, "%s_start:         ", fn->name->chars);
                    append(code, "    pop    r10");
                } else {
                    printf("Warning: unused function %s\n", fn->name->chars);
                }
            } break;
            case OP_FUNCTION_END: {
                Function *fn = AS_FUNCTION(READ_CONSTANT());
                if (fn->called) {
                    append(code, "    /* end of: %s    */", fn->name->chars);
                    append(code, "%s_end:", fn->name->chars);
                    if (fn->ret != DATA_NULL) {
                        append(code, "    pop rax");
                        append(code, "    push rax");
                    }
                }
            } break;
            case OP_CALL: {
                Function *fn = AS_FUNCTION(READ_CONSTANT());
                append(code, "    /* call: %s    */", fn->name->chars);
                append(code, "    call %s_start", fn->name->chars);
            } break;
            case OP_RETURN: {
                append(code, "    /*    return    */");
                append(code, "    push   r10");
                append(code, "    ret");
            } break;
            case OP_DEFINE_PTR: {
                const char *name = READ_STRING()->chars;
                int size = AS_INT(READ_CONSTANT());
                append(mems, ".comm %s, %d", name, size);
            } break;
            case OP_DIVIDE: {
                append(code, "    /*    __SYS_DIVMOD    */");
                append(code, "    xor    rdx, rdx");
                append(code, "    pop    rbx");
                append(code, "    pop    rax");
                append(code, "    div    rbx");
                append(code, "    push   rdx");
                append(code, "    push   rax");
            } break;
            case OP_DROP: {
                append(code, "    /*    drop    */");
                append(code, "    pop    rax");
            } break;
            case OP_DUP: {
                append(code, "    /*    dup    */");
                append(code, "    pop    rax");
                append(code, "    push   rax");
                append(code, "    push   rax");
            } break;
            case OP_EQUAL: {
                append(code, "    /*    ==    */");
                append(code, "    xor    rcx, rcx");
                append(code, "    mov    $1,  rdx");
                append(code, "    pop    rbx");
                append(code, "    pop    rax");
                append(code, "    cmp    rbx, rax");
                append(code, "    cmove  rdx, rcx");
                append(code, "    push   rcx");
            } break;
            case OP_GREATER: {
                append(code, "    /*    >    */");
                append(code, "    xor    rcx, rcx");
                append(code, "    mov    $1,  rdx");
                append(code, "    pop    rbx");
                append(code, "    pop    rax");
                append(code, "    cmp    rbx, rax");
                append(code, "    cmovg  rdx, rcx");
                append(code, "    push   rcx");
            } break;
            case OP_GREATER_EQUAL: {
                append(code, "    /*    >=    */");
                append(code, "    xor    rcx, rcx");
                append(code, "    mov    $1,  rdx");
                append(code, "    pop    rbx");
                append(code, "    pop    rax");
                append(code, "    cmp    rbx, rax");
                append(code, "    cmovge rdx, rcx");
                append(code, "    push   rcx");
            } break;
            case OP_INC: {
                append(code, "    /*    inc    */");
                append(code, "    pop    rax");
                append(code, "    inc    rax");
                append(code, "    push   rax");
            } break;
            case OP_LESS: {
                append(code, "    /*    <    */");
                append(code, "    xor    rcx, rcx");
                append(code, "    mov    $1,  rdx");
                append(code, "    pop    rbx");
                append(code, "    pop    rax");
                append(code, "    cmp    rbx, rax");
                append(code, "    cmovl  rdx, rcx");
                append(code, "    push   rcx");
            } break;
            case OP_LESS_EQUAL: {
                append(code, "    /*    <=    */");
                append(code, "    xor    rcx, rcx");
                append(code, "    mov    $1,  rdx");
                append(code, "    pop    rbx");
                append(code, "    pop    rax");
                append(code, "    cmp    rbx, rax");
                append(code, "    cmovle rdx, rcx");
                append(code, "    push   rcx");
            } break;
            case OP_LOAD8: {
                append(code, "    /*    @8    */");
                append(code, "    pop    rax");
                append(code, "    xor    rbx, rbx");
                append(code, "    mov    (rax), bl");
                append(code, "    push   rbx");
            } break;
            case OP_MULTIPLY: {
                append(code, "    /*    __SYS_MUL    */");
                append(code, "    pop    rax");
                append(code, "    pop    rbx");
                append(code, "    mul    rbx");
                append(code, "    push   rax");
            } break;
            case OP_NOT_EQUAL: {
                append(code, "    /*    !=    */");
                append(code, "    xor    rcx, rcx");
                append(code, "    mov    $1,  rdx");
                append(code, "    pop    rbx");
                append(code, "    pop    rax");
                append(code, "    cmp    rbx, rax");
                append(code, "    cmovne rdx, rcx");
                append(code, "    push   rcx");
            } break;
            case OP_OR: {
                printf("Not implemented\n");
                return COMPILER_GENERATOR_ERROR;
            } break;
            case OP_OVER: {
                append(code, "    /*    over    */");
                append(code, "    pop    rax");
                append(code, "    pop    rbx");
                append(code, "    push   rbx");
                append(code, "    push   rax");
                append(code, "    push   rbx");
            } break;
            case OP_PRINT: {
                append(code, "    /*    print    */");
                append(code, "    pop    rdi");
                append(code, "    call   dump");
            } break;
            case OP_SAVE8: {
                append(code, "    /*    !8    */");
                append(code, "    pop    rbx");
                append(code, "    pop    rax");
                append(code, "    mov    bl, (rax)");
            } break;
            case OP_SWAP: {
                append(code, "    /*    swap    */");
                append(code, "    pop    rax");
                append(code, "    pop    rbx");
                append(code, "    push   rax");
                append(code, "    push   rbx");
            } break;
            case OP_SUBSTRACT: {
                append(code, "    /*    __SYS_SUB    */");
                append(code, "    pop    rax");
                append(code, "    pop    rbx");
                append(code, "    sub    rax, rbx");
                append(code, "    push   rbx");
            } break;
            case OP_SYS0: {
                append(code, "    /*    __SYS_CALL0    */");
                append(code, "    pop    rax");
                append(code, "    syscall");
                append(code, "    push   rax");
            } break;
            case OP_SYS1: {
                append(code, "    /*    __SYS_CALL1    */");
                append(code, "    pop    rax");
                append(code, "    pop    rdi");
                append(code, "    syscall");
                append(code, "    push   rax");
            } break;
            case OP_SYS2: {
                append(code, "    /*    __SYS_CALL2    */");
                append(code, "    pop    rax");
                append(code, "    pop    rdi");
                append(code, "    pop    rsi");
                append(code, "    syscall");
                append(code, "    push   rax");
            } break;
            case OP_SYS3: {
                append(code, "    /*    __SYS_CALL3    */");
                append(code, "    pop    rax");
                append(code, "    pop    rdi");
                append(code, "    pop    rsi");
                append(code, "    pop    rdx");
                append(code, "    syscall");
                append(code, "    push   rax");
            } break;
            case OP_SYS4: {
                append(code, "    /*    __SYS_CALL4    */");
                append(code, "    pop    rax");
                append(code, "    pop    rdi");
                append(code, "    pop    rsi");
                append(code, "    pop    rdx");
                append(code, "    pop    r10");
                append(code, "    syscall");
                append(code, "    push   rax");
            } break;
            case OP_SYS5: {
                append(code, "    /*    __SYS_CALL5    */");
                append(code, "    pop    rax");
                append(code, "    pop    rdi");
                append(code, "    pop    rsi");
                append(code, "    pop    rdx");
                append(code, "    pop    r10");
                append(code, "    pop    r9");
                append(code, "    syscall");
                append(code, "    push   rax");
            } break;
            case OP_SYS6: {
                append(code, "    /*    __SYS_CALL6    */");
                append(code, "    pop    rax");
                append(code, "    pop    rdi");
                append(code, "    pop    rsi");
                append(code, "    pop    rdx");
                append(code, "    pop    r10");
                append(code, "    pop    r8");
                append(code, "    pop    r9");
                append(code, "    syscall");
                append(code, "    push   rax");
            } break;
            case OP_TAKE: {
                append(code, "    /*    take    */");
                append(code, "    pop    rax");
                append(code, "    push   rax");
            } break;
            // Special
            case OP_END: {
                append(code, "    /*    EOF    */");
                append(code, "    mov    $60,   rax");
                append(code, "    xor    rdi, rdi");
                append(code, "    syscall");
                return COMPILER_OK;
            }
            default: {
                printf("Not implemented\n");
                return COMPILER_GENERATOR_ERROR;
            }
        }
    }
}

#undef READ_BYTE
#undef READ_CONSTANT
#undef READ_STRING
#undef READ_SHORT
