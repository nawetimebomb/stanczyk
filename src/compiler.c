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
#include <stdarg.h>
#include <string.h>

#include "common.h"
#include "chunk.h"
#include "compiler.h"
#include "bytecode.h"
#include "memory.h"
#include "preprocessor.h"
#include "debug.h"
#include "generator.h"
#include "printer.h"

Writer writer;

static void init_writer_array(OutputArray *array) {
    array->count = 0;
    array->capacity = 0;
    array->items = NULL;
}

static CompilerResult generate() {
#if defined(__linux__)
    print_cli("[ info ]", "Compiling code for Linux");
    return generate_x64_linux(&writer, &writer.executable, &writer.writeable);
#elif defined(_WIN32) || defined(_WIN64) || defined(__CYGWIN__)
    print_cli("[ error ]", "Windows is not supported");
    return COMPILER_OS_ERROR;
#elif defined(__APPLE__) || defined(__MACH__)
    print_cli("[ error ]", "Mac is not supported");
    return COMPILER_OS_ERROR;
#else
    print_cli("[ error ]", " Operating System not supported");
    return COMPILER_OS_ERROR;
#endif
}

static CompilerResult write() {
    // TODO: Select name of file dinamically
    FILE *out = fopen("output.asm", "w");

    fprintf(out, "format ELF64 executable\n");
    fprintf(out, "segment readable executable\n");
    fprintf(out, "dump:\n");
    fprintf(out, "    mov     r9, -3689348814741910323\n");
    fprintf(out, "    sub     rsp, 40\n");
    fprintf(out, "    mov     BYTE [rsp+31], 10\n");
    fprintf(out, "    lea     rcx, [rsp+30]\n");
    fprintf(out, ".L2:\n");
    fprintf(out, "    mov     rax, rdi\n");
    fprintf(out, "    lea     r8, [rsp+32]\n");
    fprintf(out, "    mul     r9\n");
    fprintf(out, "    mov     rax, rdi\n");
    fprintf(out, "    sub     r8, rcx\n");
    fprintf(out, "    shr     rdx, 3\n");
    fprintf(out, "    lea     rsi, [rdx+rdx*4]\n");
    fprintf(out, "    add     rsi, rsi\n");
    fprintf(out, "    sub     rax, rsi\n");
    fprintf(out, "    add     eax, 48\n");
    fprintf(out, "    mov     BYTE [rcx], al\n");
    fprintf(out, "    mov     rax, rdi\n");
    fprintf(out, "    mov     rdi, rdx\n");
    fprintf(out, "    mov     rdx, rcx\n");
    fprintf(out, "    sub     rcx, 1\n");
    fprintf(out, "    cmp     rax, 9\n");
    fprintf(out, "    ja      .L2\n");
    fprintf(out, "    lea     rax, [rsp+32]\n");
    fprintf(out, "    mov     edi, 1\n");
    fprintf(out, "    sub     rdx, rax\n");
    fprintf(out, "    xor     eax, eax\n");
    fprintf(out, "    lea     rsi, [rsp+32+rdx]\n");
    fprintf(out, "    mov     rdx, r8\n");
    fprintf(out, "    mov     rax, 1\n");
    fprintf(out, "    syscall\n");
    fprintf(out, "    add     rsp, 40\n");
    fprintf(out, "    ret\n");
    fprintf(out, "entry start\n");
    fprintf(out, "start:\n");

    for (int i = 0; i < writer.executable.count; i++) {
        fprintf(out, "%s\n", writer.executable.items[i]);
    }

    fprintf(out, "segment readable writeable\n");

    for (int i = 0; i < writer.writeable.count; i++) {
        char *str = writer.writeable.items[i];
        int count = 0;
        int length = strlen(str);
        fprintf(out, "str_%d: db ", i);

        for (char c = *str; c; c = *++str) {
            fprintf(out, "%d", c);
            if (count != length - 1) fprintf(out, ",");
            count++;
        }

        fprintf(out, "\n");
    }

    // TODO: Get memory dinamically
    fprintf(out, "mem: rb 640000\n");

    fclose(out);

    // TODO: move these out.
    print_cli("[ info ]", "Running the FASM Assembler");
    system("fasm output.asm");
#ifndef DEBUG_COMPILED
    print_cli("[ info ]", "Cleaning up");
    system("rm output.asm");
#endif
    system("./output");

    return COMPILER_OK;
}

CompilerResult compile(const char *source) {
    Chunk *chunk = malloc(sizeof(Chunk));
    init_chunk(chunk);
    init_writer_array(&writer.executable);
    init_writer_array(&writer.writeable);

    const char *processed = process(source);
    bytecode(processed, chunk);

    if (chunk->erred) {
        return COMPILER_BYTECODE_ERROR;
    }

    writer.chunk = chunk;
    writer.ip = chunk->code;

    CompilerResult result = generate();

    // TODO: Improve the below
    if (result) return result;
    result = write();
    if (result) return result;

    return result;
}

void append(OutputArray *array, char *format, ...) {
    va_list args;
    char *line = (char *)malloc(sizeof(char *) * 128);
    va_start(args, format);
    vsprintf(line, format, args);
    va_end(args);

    if (array->capacity < array->count + 1) {
        int prev_capacity = array->capacity;
        array->capacity = GROW_CAPACITY(prev_capacity);
        array->items = GROW_ARRAY(char *, array->items, prev_capacity, array->capacity);
    }

    array->items[array->count] = (char *)malloc(strlen(line) + 1);
    strcpy(array->items[array->count], line);
    array->count++;
    free(line);
}
