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
#include <string.h>

#include "stanczyk.h"

#include "codegen.h"

#include "assembly.h"
#include "ir_code.h"
#include "logger.h"
#include "memory.h"

typedef struct {
    IRCodeChunk *chunk;
    Code *ip;
    Assembly *assembly;
} Codegen;

Codegen *codegen;

static void start_codegen(IRCodeChunk *chunk, Assembly *assembly) {
    codegen = ALLOCATE(Codegen);
    codegen->chunk = chunk;
    codegen->ip = chunk->code;
    codegen->assembly = assembly;
}

static void stop_codegen() {
    FREE(Codegen, codegen);
}

static char *str_ascii(String *str) {
    if (str->length > 255) {
        CODEGEN_ERROR("String has more than 255 characters. Split the string");
    }
    char *result = ALLOCATE_AMOUNT(char, 255);
    char *num = ALLOCATE_AMOUNT(char, 1);

    for (char c = *str->chars; c; c = *++str->chars) {
        if (c == '\\') {
            c = *++str->chars;
            switch (c) {
                case 't': sprintf(num, "%d", 9);  break;
                case 'n': sprintf(num, "%d", 10); break;
            }
        } else {
            sprintf(num, "%u", (u8)c);
        }

        strcat(result, num);
        strcat(result, ",");
    }
    strcat(result, "0");
    FREE(char, num);
    return result;
}

static void generate_linux_x86() {
#define NEXT_BYTE() (*codegen->ip++);
    AssemblyChunk *text = &codegen->assembly->text;
    AssemblyChunk *data = &codegen->assembly->data;

    write_assembly(text, "section .text");
    write_assembly(text, "global _start");
    write_assembly(text, "print:");
    write_assembly(text, "    mov     r9, -3689348814741910323");
    write_assembly(text, "    sub     rsp, 40");
    write_assembly(text, "    mov     BYTE [rsp+31], 10");
    write_assembly(text, "    lea     rcx, [rsp+30]");
    write_assembly(text, ".L2:");
    write_assembly(text, "    mov     rax, rdi");
    write_assembly(text, "    lea     r8, [rsp+32]");
    write_assembly(text, "    mul     r9");
    write_assembly(text, "    mov     rax, rdi");
    write_assembly(text, "    sub     r8, rcx");
    write_assembly(text, "    shr     rdx, 3");
    write_assembly(text, "    lea     rsi, [rdx+rdx*4]");
    write_assembly(text, "    add     rsi, rsi");
    write_assembly(text, "    sub     rax, rsi");
    write_assembly(text, "    add     eax, 48");
    write_assembly(text, "    mov     BYTE [rcx], al");
    write_assembly(text, "    mov     rax, rdi");
    write_assembly(text, "    mov     rdi, rdx");
    write_assembly(text, "    mov     rdx, rcx");
    write_assembly(text, "    sub     rcx, 1");
    write_assembly(text, "    cmp     rax, 9");
    write_assembly(text, "    ja      .L2");
    write_assembly(text, "    lea     rax, [rsp+32]");
    write_assembly(text, "    mov     edi, 1");
    write_assembly(text, "    sub     rdx, rax");
    write_assembly(text, "    xor     eax, eax");
    write_assembly(text, "    lea     rsi, [rsp+32+rdx]");
    write_assembly(text, "    mov     rdx, r8");
    write_assembly(text, "    mov     rax, 1");
    write_assembly(text, "    syscall");
    write_assembly(text, "    add     rsp, 40");
    write_assembly(text, "    ret");
    write_assembly(text, "_start:");
    write_assembly(text, ";; user program definitions starts here:");

    write_assembly(data, "section .data");

    for (;;) {
        int offset = codegen->ip - codegen->chunk->code;
        Code instruction = NEXT_BYTE();
        Token *token = &instruction.token;

        write_assembly(text, "ip_%d:", offset);

        switch (instruction.type) {
            /*    ___             _            _
             *   / __|___ _ _  __| |_ __ _ _ _| |_ ___
             *  | (__/ _ \ ' \(_-<  _/ _` | ' \  _(_-<
             *   \___\___/_||_/__/\__\__,_|_||_\__/__/
             */
            case OP_PUSH_INT: {
                int value = AS_INT(instruction.operand);
                write_assembly(text, ";; %d (%s:%d:%d)", value,
                               token->filename, token->line, token->column);
                write_assembly(text, "    mov rax, %d", value);
                write_assembly(text, "    push rax");
            } break;
            case OP_PUSH_STR: {
                String *value = AS_STRING(instruction.operand);
                char *ascii_str = str_ascii(value);
                write_assembly(text, ";; %s (%s:%d:%d)", value->chars,
                               token->filename, token->line, token->column);
                write_assembly(text, "    mov rax, %d", value->length);
                write_assembly(text, "    push rax");
                write_assembly(text, "    push str_%d", data->count);
                write_assembly(data, "str_%d: db %s", data->count, ascii_str);
            } break;
            case OP_PUSH_BOOL: {
                int value = AS_INT(instruction.operand);
                write_assembly(text, ";; %.*s (%s:%d:%d)", token->length, token->start,
                               token->filename, token->line, token->column);
                write_assembly(text, "    mov rax, %d", value);
                write_assembly(text, "    push rax");
            } break;

            /*   ___     _       _         _
             *  |_ _|_ _| |_ _ _(_)_ _  __(_)__ ___
             *   | || ' \  _| '_| | ' \(_-< / _(_-<
             *  |___|_||_\__|_| |_|_||_/__/_\__/__/
             */
            case OP_ADD: {
                write_assembly(text, ";; + (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    pop rax");
                write_assembly(text, "    pop rbx");
                write_assembly(text, "    add rax, rbx");
                write_assembly(text, "    push rax");
            } break;
            case OP_SUBSTRACT: {
                write_assembly(text, ";; - (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    pop rbx");
                write_assembly(text, "    pop rax");
                write_assembly(text, "    sub rax, rbx");
                write_assembly(text, "    push rax");
            } break;
            case OP_MULTIPLY: {
                write_assembly(text, ";; * (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    pop rax");
                write_assembly(text, "    pop rbx");
                write_assembly(text, "    mul rbx");
                write_assembly(text, "    push rax");
            } break;
            case OP_DIVIDE: {
                write_assembly(text, ";; / (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    xor rdx, rdx");
                write_assembly(text, "    pop rbx");
                write_assembly(text, "    pop rax");
                write_assembly(text, "    div rbx");
                write_assembly(text, "    push rax");
            } break;
            case OP_MODULO: {
                write_assembly(text, ";; % (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    xor rdx, rdx");
                write_assembly(text, "    pop rbx");
                write_assembly(text, "    pop rax");
                write_assembly(text, "    div rbx");
                write_assembly(text, "    push rdx");
            } break;
            case OP_EQUAL: {
                write_assembly(text, ";; = (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    xor rcx, rcx");
                write_assembly(text, "    mov rdx, 1");
                write_assembly(text, "    pop rax");
                write_assembly(text, "    pop rbx");
                write_assembly(text, "    cmp rax, rbx");
                write_assembly(text, "    cmove rcx, rdx");
                write_assembly(text, "    push rcx");
            } break;
            case OP_NOT_EQUAL: {
                write_assembly(text, ";; != (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    xor rcx, rcx");
                write_assembly(text, "    mov rdx, 1");
                write_assembly(text, "    pop rax");
                write_assembly(text, "    pop rbx");
                write_assembly(text, "    cmp rax, rbx");
                write_assembly(text, "    cmovne rcx, rdx");
                write_assembly(text, "    push rcx");
            } break;
            case OP_LESS: {
                write_assembly(text, ";; < (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    xor rcx, rcx");
                write_assembly(text, "    mov rdx, 1");
                write_assembly(text, "    pop rbx");
                write_assembly(text, "    pop rax");
                write_assembly(text, "    cmp rax, rbx");
                write_assembly(text, "    cmovl rcx, rdx");
                write_assembly(text, "    push rcx");
            } break;
            case OP_LESS_EQUAL: {
                write_assembly(text, ";; <= (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    xor rcx, rcx");
                write_assembly(text, "    mov rdx, 1");
                write_assembly(text, "    pop rbx");
                write_assembly(text, "    pop rax");
                write_assembly(text, "    cmp rax, rbx");
                write_assembly(text, "    cmovle rcx, rdx");
                write_assembly(text, "    push rcx");
            } break;
            case OP_GREATER: {
                write_assembly(text, ";; > (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    xor rcx, rcx");
                write_assembly(text, "    mov rdx, 1");
                write_assembly(text, "    pop rbx");
                write_assembly(text, "    pop rax");
                write_assembly(text, "    cmp rax, rbx");
                write_assembly(text, "    cmovg rcx, rdx");
                write_assembly(text, "    push rcx");
            } break;
            case OP_GREATER_EQUAL: {
                write_assembly(text, ";; >= (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    xor rcx, rcx");
                write_assembly(text, "    mov rdx, 1");
                write_assembly(text, "    pop rbx");
                write_assembly(text, "    pop rax");
                write_assembly(text, "    cmp rax, rbx");
                write_assembly(text, "    cmovge rcx, rdx");
                write_assembly(text, "    push rcx");
            } break;
            case OP_DROP: {
                write_assembly(text, ";; drop (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    pop rax");
            } break;
            case OP_DUP: {
                write_assembly(text, ";; dup (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    pop rax");
                write_assembly(text, "    push rax");
                write_assembly(text, "    push rax");
            } break;
            case OP_PRINT: {
                write_assembly(text, ";; print (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    pop rdi");
                write_assembly(text, "    call print");
            } break;
            case OP_JUMP_IF_FALSE: {
                int value = AS_INT(instruction.operand);
                write_assembly(text, ";; do (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    pop rax");
                write_assembly(text, "    test rax, rax");
                write_assembly(text, "    jz ip_%d", value);
            } break;
            case OP_JUMP: {
                int value = AS_INT(instruction.operand);
                write_assembly(text, ";; else (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    jmp ip_%d", value);
            } break;
            case OP_LOOP: {
                int value = AS_INT(instruction.operand);
                write_assembly(text, ";; loop (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    jmp ip_%d", value);
            } break;
            case OP_SYSCALL3: {
                write_assembly(text, ";; __SYSCALL3 (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    pop rax");
                write_assembly(text, "    pop rdi");
                write_assembly(text, "    pop rsi");
                write_assembly(text, "    pop rdx");
                write_assembly(text, "    syscall");
                write_assembly(text, "    push rax");
            } break;


            /*   _  __                           _
             *  | |/ /___ _  ___ __ _____ _ _ __| |___
             *  | ' </ -_) || \ V  V / _ \ '_/ _` (_-<
             *  |_|\_\___|\_, |\_/\_/\___/_| \__,_/__/
             *            |__/
             */
            case OP_CAST:
            case OP_END_IF:
            case OP_END_LOOP: break;

            case OP_EOC: {
                write_assembly(text, ";; eof (%s:%d:%d)",
                               token->filename, token->line, token->column);
                write_assembly(text, "    mov rax, 60");
                write_assembly(text, "    mov rdi, 0");
                write_assembly(text, "    syscall");
            } return;
        }
    }
#undef NEXT_BYTE
}

void codegen_run(IRCodeChunk *chunk, Assembly *assembly) {
    start_codegen(chunk, assembly);

#if defined(__linux__)
    generate_linux_x86();
#elif defined(_WIN32) || defined(_WIN64) || defined(__CYGWIN__)
    CODEGEN_ERROR("Sorry, this Operating System is not supported at this moment");
#elif defined(__APPLE__) || defined(__MACH__)
    CODEGEN_ERROR("Sorry, this Operating System is not supported at this moment");
#else
    CODEGEN_ERROR("Sorry, this Operating System is not supported at this moment");
#endif

    stop_codegen();
}
