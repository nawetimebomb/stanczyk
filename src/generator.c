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
#include "compiler.h"
#include "object.h"
#include "debug.h"

#define READ_BYTE() (*writer->ip++)
#define READ_CONSTANT() (writer->chunk->constants.values[READ_BYTE()])
#define READ_STRING() AS_STRING(READ_CONSTANT())
#define READ_SHORT() (writer->ip += 2, (u16)((writer->ip[-2] << 8) | writer->ip[-1]))

CompilerResult generate_x64_linux(Writer *writer,
                                  OutputArray *code,
                                  OutputArray *writeable) {
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
                int value = AS_NUMBER(READ_CONSTANT());
                append(code, "    /*    %d    */", value);
                append(code, "    mov    $%d, rax", value);
                append(code, "    push   rax");
            } break;
            case OP_PUSH_STR: {
                String *value = READ_STRING();
                append(code, "    /*    len: %d str: str_%d    */",
                       value->length, writeable->count);
                append(code, "    mov    $%d, rax", value->length);
                append(code, "    push   rax");
                append(code, "    lea    str_%d(rip), rax", writeable->count);
                append(code, "    push   rax");
                append(writeable, "%s", value->chars);
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
            case OP_MEMORY: {
                append(code, "    /*    memory    */");
                append(code, "    lea   mem(rip), rax");
                append(code, "    push  rax");
            } break;
            // Intrinsics
            case OP_ADD: {
                append(code, "    /*    +    */");
                append(code, "    pop    rax");
                append(code, "    pop    rbx");
                append(code, "    add    rbx, rax");
                append(code, "    push   rax");
            } break;
            case OP_AND: {
                printf("Not implemented\n");
                return COMPILER_GENERATOR_ERROR;
            } break;
            case OP_DEC: {
                append(code, "    /*    dec    */");
                append(code, "    pop    rax");
                append(code, "    dec    rax");
                append(code, "    push   rax");
            } break;
            case OP_DIVIDE: {
                append(code, "    /*    /    */");
                append(code, "    xor    rdx, rdx");
                append(code, "    pop    rbx");
                append(code, "    pop    rax");
                append(code, "    div    rbx");
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
                append(code, "    /*    *    */");
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
            case OP_RETURN: {
                printf("Not implemented\n");
                return COMPILER_GENERATOR_ERROR;
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
                append(code, "    /*    -    */");
                append(code, "    pop    rax");
                append(code, "    pop    rbx");
                append(code, "    sub    rax, rbx");
                append(code, "    push   rbx");
            } break;
            case OP_SYS4: {
                append(code, "    /*    sys4    */");
                append(code, "    pop    rax");
                append(code, "    pop    rdi");
                append(code, "    pop    rsi");
                append(code, "    pop    rdx");
                append(code, "    syscall");
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
