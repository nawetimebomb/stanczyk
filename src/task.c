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

#include "compiler.h"
#include "printer.h"
#include "task.h"

extern CompilerOptions options;

static CompilerResult write(Writer *writer, Compiler *compiler) {
    // TODO: Select name of file dinamically
    FILE *out = fopen("output.s", "w");

    fprintf(out, ".att_syntax noprefix\n");
    fprintf(out, ".global main\n");
    fprintf(out, "dump:\n");
    fprintf(out, "   movabsq $-3689348814741910323, r8\n");
    fprintf(out, "   subq    $40, rsp\n");
    fprintf(out, "   movb    $10, 31(rsp)\n");
    fprintf(out, "   leaq    30(rsp), rcx\n");
    fprintf(out, ".L2:\n");
    fprintf(out, "   movq    rdi, rax\n");
    fprintf(out, "   mulq    r8\n");
    fprintf(out, "   movq    rdi, rax\n");
    fprintf(out, "   shrq    $3, rdx\n");
    fprintf(out, "   leaq    (rdx,rdx,4), rsi\n");
    fprintf(out, "   addq    rsi, rsi\n");
    fprintf(out, "   subq    rsi, rax\n");
    fprintf(out, "   movq    rcx, rsi\n");
    fprintf(out, "   subq    $1, rcx\n");
    fprintf(out, "   addl    $48, eax\n");
    fprintf(out, "   movb    al, 1(rcx)\n");
    fprintf(out, "   movq    rdi, rax\n");
    fprintf(out, "   movq    rdx, rdi\n");
    fprintf(out, "   cmpq    $9, rax\n");
    fprintf(out, "   ja      .L2\n");
    fprintf(out, "   leaq    32(rsp), rdx\n");
    fprintf(out, "   movl    $1, edi\n");
    fprintf(out, "   subq    rsi, rdx\n");
    fprintf(out, "   call    write\n");
    fprintf(out, "   addq    $40, rsp\n");
    fprintf(out, "   ret\n");
    fprintf(out, "main:\n");

    for (int i = 0; i < writer->code.count; i++) {
        fprintf(out, "%s\n", writer->code.items[i]);
    }

    // fprintf(out, ".section d\n");

    fprintf(out, "\n\n");

    for (int i = 0; i < writer->writeable.count; i++) {
        char *str = writer->writeable.items[i];
        fprintf(out, "str_%d: .string \"%s\"\n", i, str);
    }

    // for (int i = 0; i < writer->writeable.count; i++) {
    //     char *str = writer->writeable.items[i];
    //     int count = 0;
    //     int length = strlen(str);
    //     fprintf(out, "str_%d: db ", i);

    //     for (char c = *str; c; c = *++str) {
    //         fprintf(out, "%d", c);
    //         if (count != length - 1) fprintf(out, ",");
    //         count++;
    //     }

    //     fprintf(out, "\n");
    // }

    // // TODO: Get memory dinamically
    fprintf(out, ".comm mem, 80\n");

    fclose(out);

    // TODO: move these out.
    print_cli("[ info ]", "Running Assembler");
    system("as output.s -o output.o");
    print_cli("[ info ]", "Running the GCC Linker");
    system("gcc -L. output.o -o output -g");
    //system("fasm output.asm");
#ifndef DEBUG_COMPILED
    print_cli("[ info ]", "Cleaning up");
    system("rm output.asm");
#endif
    if (compiler->options.run) system("./output");

    return COMPILER_OK;
}

CompilerResult run(Writer *writer, Compiler *compiler) {
    return write(writer, compiler);
}
