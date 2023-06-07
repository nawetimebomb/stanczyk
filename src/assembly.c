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
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

#include "assembly.h"
#include "memory.h"

static void start_assembly_chunk(AssemblyChunk *chunk) {
    chunk->start = 32;
    chunk->capacity = 0;
    chunk->count = 0;
    chunk->lines = NULL;
}

static void stop_assembly_chunk(AssemblyChunk *chunk) {
    FREE_ARRAY(char *, chunk->lines, chunk->capacity);
    start_assembly_chunk(chunk);
}

Assembly *start_assembly() {
    Assembly *result = ALLOCATE(Assembly);
    start_assembly_chunk(&result->text);
    start_assembly_chunk(&result->data);
    start_assembly_chunk(&result->bss);
    return result;
}

void stop_assembly(Assembly *assembly) {
    stop_assembly_chunk(&assembly->text);
    stop_assembly_chunk(&assembly->data);
    stop_assembly_chunk(&assembly->bss);
    FREE(Assembly, assembly);
}

void write_assembly(AssemblyChunk *chunk, const char *format, ...) {
    va_list args;
    char line[256];
    va_start(args, format);
    vsprintf(line, format, args);
    va_end(args);

    if (chunk->capacity < chunk->count + 1) {
        int prev_capacity = chunk->capacity;
        chunk->capacity = GROW_CAPACITY(prev_capacity, chunk->start);
        chunk->lines = GROW_ARRAY(char *, chunk->lines, prev_capacity, chunk->capacity);
    }

    int len = strlen(line) + 1;
    chunk->lines[chunk->count] = ALLOCATE_AMOUNT(char, len);
    memcpy(chunk->lines[chunk->count], line, len);
    chunk->count++;
    //FREE(char, line);
}
