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
                                  OutputArray *executable,
                                  OutputArray *writeable) {
    for (;;) {
#ifdef DEBUG_BYTECODE
        disassemble_instruction(writer->chunk, (int)(writer->ip - writer->chunk->code));
#endif

        u8 instruction;
        int line = writer->chunk->lines[writer->ip - writer->chunk->code];
        append(executable,
               "ip_%d: %*s; (line %d)",
               writer->ip - writer->chunk->code, 25, "", line);
        switch (instruction = READ_BYTE()) {
            // Constants
            case OP_PUSH_INT: {
                int value = AS_NUMBER(READ_CONSTANT());
                append(executable, "    ;; %d", value);
                append(executable, "    mov    rax, %d", value);
                append(executable, "    push   rax");
            } break;
            case OP_PUSH_STR: {
                String *value = READ_STRING();
                append(executable, "    ;; %d %s", value->length, value->chars);
                append(executable, "    mov    rax, %d", strlen(value->chars));
                append(executable, "    push   rax");
                append(executable, "    push   str_%d", writeable->count);
                append(writeable, "%s", value->chars);
            } break;
            // Keywords
            case OP_JUMP: {
                u16 offset = READ_SHORT();
                int result_ip = (writer->ip - writer->chunk->code) + offset;
                append(executable, "    ;; else (ip_%d)", result_ip);
                append(executable, "    jmp    ip_%d", result_ip);
            } break;
            case OP_JUMP_IF_FALSE: {
                u16 offset = READ_SHORT();
                int result_ip = (writer->ip - writer->chunk->code) + offset;
                append(executable, "    ;; do (ip_%d)", result_ip);
                append(executable, "    pop    rax");
                append(executable, "    test   rax, rax");
                append(executable, "    jz     ip_%d", result_ip);
            } break;
            case OP_LOOP: {
                u16 offset = READ_SHORT();
                int result_ip = (writer->ip - writer->chunk->code) - offset;
                append(executable, "    ;; loop (ip_%d)", result_ip);
                append(executable, "    jmp    ip_%d", result_ip);
            } break;
            case OP_MEMORY: {
                append(executable, "    ;; memory");
                append(executable, "    push mem");
            } break;
            // Intrinsics
            case OP_ADD: {
                append(executable, "    ;; +");
                append(executable, "    pop    rax");
                append(executable, "    pop    rbx");
                append(executable, "    add    rax, rbx");
                append(executable, "    push   rax");
            } break;
            case OP_AND: {
                printf("Not implemented\n");
                return COMPILER_GENERATOR_ERROR;
            } break;
            case OP_DEC: {
                append(executable, "    ;; dec");
                append(executable, "    pop    rax");
                append(executable, "    dec    rax");
                append(executable, "    push   rax");
            } break;
            case OP_DIVIDE: {
                append(executable, "    ;; /");
                append(executable, "    xor    rdx, rdx");
                append(executable, "    pop    rbx");
                append(executable, "    pop    rax");
                append(executable, "    div    rax");
                append(executable, "    push   rax         ; quotient");
                append(executable, "    push   rbx         ; remainder");
            } break;
            case OP_DROP: {
                append(executable, "    ;; drop");
                append(executable, "    pop    rax");
            } break;
            case OP_DUP: {
                append(executable, "    ;; dup");
                append(executable, "    pop    rax");
                append(executable, "    push   rax");
                append(executable, "    push   rax");
            } break;
            case OP_EQUAL: {
                append(executable, "    ;; ==");
                append(executable, "    mov    rcx, 1");
                append(executable, "    xor    rdx, rdx");
                append(executable, "    pop    rbx");
                append(executable, "    pop    rax");
                append(executable, "    cmp    rax, rbx");
                append(executable, "    cmove  rdx, rcx");
                append(executable, "    push   rdx");
            } break;
            case OP_GREATER: {
                append(executable, "    ;; >");
                append(executable, "    mov    rcx, 1");
                append(executable, "    xor    rdx, rdx");
                append(executable, "    pop    rbx");
                append(executable, "    pop    rax");
                append(executable, "    cmp    rax, rbx");
                append(executable, "    cmovg  rdx, rcx");
                append(executable, "    push   rdx");
            } break;
            case OP_GREATER_EQUAL: {
                append(executable, "    ;; >=");
                append(executable, "    mov    rcx, 1");
                append(executable, "    xor    rdx, rdx");
                append(executable, "    pop    rbx");
                append(executable, "    pop    rax");
                append(executable, "    cmp    rax, rbx");
                append(executable, "    cmovge rdx, rcx");
                append(executable, "    push   rdx");
            } break;
            case OP_INC: {
                append(executable, "    ;; inc");
                append(executable, "    pop    rax");
                append(executable, "    inc    rax");
                append(executable, "    push   rax");
            } break;
            case OP_LESS: {
                append(executable, "    ;; <");
                append(executable, "    mov    rcx, 1");
                append(executable, "    xor    rdx, rdx");
                append(executable, "    pop    rbx");
                append(executable, "    pop    rax");
                append(executable, "    cmp    rax, rbx");
                append(executable, "    cmovl  rdx, rcx");
                append(executable, "    push   rdx");
            } break;
            case OP_LESS_EQUAL: {
                append(executable, "    ;; <=");
                append(executable, "    mov    rcx, 1");
                append(executable, "    xor    rdx, rdx");
                append(executable, "    pop    rbx");
                append(executable, "    pop    rax");
                append(executable, "    cmp    rax, rbx");
                append(executable, "    cmovle rdx, rcx");
                append(executable, "    push   rdx");
            } break;
            case OP_LOAD8: {
                append(executable, "    ;; @8");
                append(executable, "    pop    rax");
                append(executable, "    xor    rbx, rbx");
                append(executable, "    mov    bl, [rax]");
                append(executable, "    push   rbx");
            } break;
            case OP_MULTIPLY: {
                append(executable, "    ;; *");
                append(executable, "    pop    rax");
                append(executable, "    pop    rbx");
                append(executable, "    mul    rbx");
                append(executable, "    push   rax");
            } break;
            case OP_NOT_EQUAL: {
                append(executable, "    ;; !=");
                append(executable, "    mov    rcx, 1");
                append(executable, "    xor    rdx, rdx");
                append(executable, "    pop    rbx");
                append(executable, "    pop    rax");
                append(executable, "    cmp    rax, rbx");
                append(executable, "    cmovne rdx, rcx");
                append(executable, "    push   rdx");
            } break;
            case OP_OR: {
                printf("Not implemented\n");
                return COMPILER_GENERATOR_ERROR;
            } break;
            case OP_OVER: {
                append(executable, "    ;; over");
                append(executable, "    pop    rax");
                append(executable, "    pop    rbx");
                append(executable, "    push   rbx");
                append(executable, "    push   rax");
                append(executable, "    push   rbx");
            } break;
            case OP_PRINT: {
                append(executable, "    ;; print");
                append(executable, "    pop    rdi");
                append(executable, "    call   dump");
            } break;
            case OP_RETURN: {
                printf("Not implemented\n");
                return COMPILER_GENERATOR_ERROR;
            } break;
            case OP_SAVE8: {
                append(executable, "    ;; !8");
                append(executable, "    pop    rbx");
                append(executable, "    pop    rax");
                append(executable, "    mov    [rax], bl");
            } break;
            case OP_SWAP: {
                append(executable, "    ;; swap");
                append(executable, "    pop    rax");
                append(executable, "    pop    rbx");
                append(executable, "    push   rax");
                append(executable, "    push   rbx");
            } break;
            case OP_SUBSTRACT: {
                append(executable, "    ;; -");
                append(executable, "    pop    rax");
                append(executable, "    pop    rbx");
                append(executable, "    sub    rbx, rax");
                append(executable, "    push   rbx");
            } break;
            case OP_SYS4: {
                append(executable, "    ;; sys4");
                append(executable, "    pop    rax");
                append(executable, "    pop    rdi");
                append(executable, "    pop    rsi");
                append(executable, "    pop    rdx");
                append(executable, "    syscall");
                append(executable, "    push   rax");
            } break;
            // Special
            case OP_END: {
                append(executable, "    ;; EOF");
                append(executable, "    mov    rax, 60");
                append(executable, "    xor    rdi, rdi");
                append(executable, "    syscall");
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
