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
#define COMPILER_VERSION "0.1"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "common.h"
#include "printer.h"
#include "compiler.h"

Compiler compiler;

static void init_file_array() {
    compiler.files.count = 0;
    compiler.files.capacity = 0;
    compiler.files.filenames = NULL;
    compiler.files.sources = NULL;
}

static char *get_workspace(const char *path) {
    char *result = malloc(256);
    memset(result, 0, 256);
    getcwd(result, 256);

    return result;
}

static char *get_compiler_dir(const char *path) {
    int len = strlen(path);
    char *dir = malloc(len + 1);
    memset(dir, 0, len + 1);
    strcpy(dir, path);

    while (len > 0) {
        len--;
        if (dir[len] == '\\' || dir[len] == '/') {
            dir[len] = '\0';
            break;
        }
    }

    return dir;
}

static void parse_arguments(int argc, const char **argv) {
    for (int i = 1; i < argc; i++) {
        const char *input = argv[i];

        if ((strcmp(input, "-r") == 0) || (strcmp(input, "-run") == 0)) {
            compiler.options.run = true;
        } else if ((strcmp(input, "-d") == 0) || (strcmp(input, "-debug") == 0)) {
            compiler.options.debug = true;
        } else if ((strcmp(input, "-o") == 0) || (strcmp(input, "-out") == 0)) {
            i++;
            compiler.options.out_file = argv[i];
        } else if ((strcmp(input, "-h") == 0) || (strcmp(input, "-help") == 0)) {
            print_help();
            exit(0);
        } else if (strstr(input, ".sk")) {
            compiler.options.entry_file = input;
        } else {
            print_cli_error();
        }
    }
}

int main(int argc, const char **argv) {
    if (argc < 2) {
        print_cli_error();
    }

    init_file_array();
    parse_arguments(argc, argv);
    compiler.options.workspace = get_workspace(compiler.options.entry_file);
    compiler.options.compiler_dir = get_compiler_dir(argv[0]);

    CompilerResult result = compile(&compiler);
    Timers *timers = &compiler.timers;

    double total_time = timers->frontend + timers->generator +
        timers->writer + timers->backend;
    print_cli("[ info ]", "Compilation timers:");
    printf("\tFront-end compiler : %fs\n", timers->frontend);
    printf("\tCode generator     : %fs\n", timers->generator);
    printf("\tAssembly output    : %fs\n", timers->writer);
    printf("\tBack-end compiler  : %fs\n", timers->backend);
    printf(STYLE_BOLD"\tTotal time         : %fs\n"STYLE_OFF, total_time);

    if (compiler.options.run) system("./output");

    return result;
}
