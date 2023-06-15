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
#include <time.h>

#include "common.h"
#include "chunk.h"
#include "compiler.h"
#include "bytecode.h"
#include "memory.h"
#include "fileman.h"
#include "debug.h"
#include "generator.h"
#include "printer.h"
#include "task.h"

extern CompilerOptions options;

Writer writer;

static void init_writer_array(OutputArray *array) {
    array->start = 32;
    array->count = 0;
    array->capacity = 0;
    array->items = NULL;
}

static CompilerResult generate() {
#if defined(__linux__)
    print_cli("[ info ]", "Compiling code for Linux");
    return generate_x64_linux(&writer);
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

CompilerResult compile(Compiler *compiler) {
    Chunk *chunk = malloc(sizeof(Chunk));

    init_writer_array(&writer.code);
    init_writer_array(&writer.strs);
    init_writer_array(&writer.mems);
    init_writer_array(&writer.flts);

    chunk = bytecode(compiler);

    if (chunk->erred) {
        compiler->failed = true;
        return COMPILER_BYTECODE_ERROR;
    }

    writer.chunk = chunk;
    writer.ip = chunk->code;

    double START = (double)clock() / CLOCKS_PER_SEC;
    CompilerResult result = generate();
    double END = (double)clock() / CLOCKS_PER_SEC;
    compiler->timers.generator = END - START;

    // TODO: Improve the below
    if (result) {
        compiler->failed = true;
        return result;
    }

    return run(&writer, compiler);
}

void append(OutputArray *array, char *format, ...) {
    va_list args;
    char *line = (char *)malloc(sizeof(char *) * 128);
    va_start(args, format);
    vsprintf(line, format, args);
    va_end(args);

    if (array->capacity < array->count + 1) {
        int prev_capacity = array->capacity;
        array->capacity = GROW_CAPACITY(prev_capacity, array->start);
        array->items = GROW_ARRAY(char *, array->items, prev_capacity, array->capacity);
    }

    array->items[array->count] = (char *)malloc(strlen(line) + 1);
    strcpy(array->items[array->count], line);
    array->count++;
    free(line);
}
