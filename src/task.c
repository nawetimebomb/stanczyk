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
#include <time.h>

#include "compiler.h"
#include "memory.h"
#include "printer.h"
#include "task.h"

static CompilerResult write(Writer *writer, Compiler *compiler) {
    double START = (double)clock() / CLOCKS_PER_SEC;
    // TODO: Select name of file dinamically
    FILE *out = fopen("output.s", "w");

    fprintf(out, ".att_syntax noprefix\n");
    fprintf(out, ".global main\n");
    fprintf(out, "dump:\n");
    fprintf(out, "    movabsq $-3689348814741910323, r8\n");
    fprintf(out, "    subq    $40, rsp\n");
    fprintf(out, "    movb    $10, 31(rsp)\n");
    fprintf(out, "    leaq    30(rsp), rcx\n");
    fprintf(out, ".L2:\n");
    fprintf(out, "    movq    rdi, rax\n");
    fprintf(out, "    mulq    r8\n");
    fprintf(out, "    movq    rdi, rax\n");
    fprintf(out, "    shrq    $3, rdx\n");
    fprintf(out, "    leaq    (rdx,rdx,4), rsi\n");
    fprintf(out, "    addq    rsi, rsi\n");
    fprintf(out, "    subq    rsi, rax\n");
    fprintf(out, "    movq    rcx, rsi\n");
    fprintf(out, "    subq    $1, rcx\n");
    fprintf(out, "    addl    $48, eax\n");
    fprintf(out, "    movb    al, 1(rcx)\n");
    fprintf(out, "    movq    rdi, rax\n");
    fprintf(out, "    movq    rdx, rdi\n");
    fprintf(out, "    cmpq    $9, rax\n");
    fprintf(out, "    ja      .L2\n");
    fprintf(out, "    leaq    32(rsp), rdx\n");
    fprintf(out, "    movl    $1, edi\n");
    fprintf(out, "    subq    rsi, rdx\n");
    fprintf(out, "    call    write\n");
    fprintf(out, "    addq    $40, rsp\n");
    fprintf(out, "    ret\n");
    fprintf(out, "main:\n");
    // fprintf(out, "    mov    rsp, rbp  \n");
    // fprintf(out, "    sub    $1024, rsp\n");
    // fprintf(out, "    and    $-16, rsp \n");

    for (int i = 0; i < writer->code.count; i++) {
        fprintf(out, "%s\n", writer->code.items[i]);
    }

    // fprintf(out, ".section d\n");

    if (writer->strs.count > 0) {
        fprintf(out, "\n\n");

        for (int i = 0; i < writer->strs.count; i++) {
            char *str = writer->strs.items[i];
            fprintf(out, "str_%d: .string \"%s\"\n", i, str);
        }
    }

    if (writer->flts.count > 0) {
        fprintf(out, "\n\n");

        for (int i = 0; i < writer->flts.count; i++) {
            fprintf(out, "%s\n", writer->flts.items[i]);
        }
    }

    if (writer->mems.count > 0) {
        fprintf(out, "\n\n");

        for (int i = 0; i < writer->mems.count; i++) {
            fprintf(out, "%s\n", writer->mems.items[i]);
        }
    }

    fclose(out);
    double END = (double)clock() / CLOCKS_PER_SEC;
    compiler->timers.writer = END - START;

    return COMPILER_OK;
}

CompilerResult run(Writer *writer, Compiler *compiler) {
    CompilerResult result = write(writer, compiler);

    // TODO: Update name files
    double START = (double)clock() / CLOCKS_PER_SEC;
    print_cli("[ info ]", "Running Assembler");
    system("as output.s -o output.o");
    print_cli("[ info ]", "Running the GCC Linker");

    char *gcc_command = ALLOCATE(char, 128);
    memset(gcc_command, 0, sizeof(char) * 128);
    strcpy(gcc_command, "gcc -L. output.o -o output -g");

    for (int i = 0; i < compiler->clibs.count; i++) {
        char *libname = ALLOCATE(char, 20);
        sprintf(libname, " -l%s", compiler->clibs.libs[i]->chars);
        strcat(gcc_command, libname);
        free(libname);
    }

    system(gcc_command);
#ifndef DEBUG_COMPILED
    print_cli("[ info ]", "Cleaning up");
    system("rm output.s");
    system("rm output.o");
#endif
    double END = (double)clock() / CLOCKS_PER_SEC;
    compiler->timers.backend = END - START;

    if (result) {
        compiler->failed = true;
    }

    return result;
}
