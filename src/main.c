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

#include "stanczyk.h"

#include "tasker.h"
#include "logger.h"

#include "compiler.h"
#include "memory.h"

Compiler compiler;

static void init_clib_array() {
    compiler.clibs.start = 4;
    compiler.clibs.count = 0;
    compiler.clibs.capacity = 0;
    compiler.clibs.libs = NULL;
}

static char *find_project_dir() {
    char *result = malloc(256);
    memset(result, 0, 256);
    getcwd(result, 256);

    return result;
}

static char *find_compiler_dir(const char *path) {
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
    if (strcmp(argv[1], "run") == 0) {
        set_mode(COMPILATION_MODE_RUN);
    } else if (strcmp(argv[1], "build") == 0) {
        set_mode(COMPILATION_MODE_BUILD);
    } else if (strcmp(argv[1], "help") == 0) {
        CLI_HELP();
    } else {
        CLI_ERROR("first argument should be a command but instead got %s\n"
                  "E.g.\n" "\tskc run myfile.sk\n" "\t    ^^^\n"
                  "See below for allowed commands", argv[1]);
    }

    for (int i = 2; i < argc; i++) {
        const char *input = argv[i];

        if ((strcmp(input, "-r") == 0) || (strcmp(input, "-run") == 0)) {
            set_flag(COMPILATION_FLAG_RUN, true);
        } else if ((strcmp(input, "-C") == 0) || (strcmp(input, "-clean") == 0)) {
            set_flag(COMPILATION_FLAG_RUN, true);
            set_flag(COMPILATION_FLAG_CLEAN, true);
        } else if ((strcmp(input, "-d") == 0) || (strcmp(input, "-debug") == 0)) {
            set_flag(COMPILATION_FLAG_DEBUG, true);
        } else if ((strcmp(input, "-o") == 0) || (strcmp(input, "-out") == 0)) {
            i++;
            set_output(argv[i]);
        } else if ((strcmp(input, "-s") == 0) || (strcmp(input, "-silent") == 0)) {
            set_flag(COMPILATION_FLAG_SILENT, true);
        } else if (strstr(argv[i], ".sk")) {
            set_entry(argv[i]);
        } else {
            CLI_ERROR("unknown option %s in arguments\n"
                      "You can get a list of allowed arguments "
                      "by running skc -help\n", argv[i]);
        }
    }
}

int main(int argc, const char **argv) {
    if (argc < 2) {
        CLI_WELCOME();
    }

    start_stanczyk();

    init_clib_array();

    parse_arguments(argc, argv);

    if (!compilation_ready()) {
        CLI_ERROR("missing entry file in the arguments given to skc\n"
                  "You need to provide an .sk file as an argument, after the command\n"
                  "E.g.:\n" "\tskc run myfile.sk\n" "\t        ^^^^^^^^^\n");
    }

    set_directories(find_compiler_dir(argv[0]), find_project_dir());

    run_tasker();

    compile(&compiler);

    if (get_flag(COMPILATION_FLAG_RUN) && !compilation_failed()) {
        system("./output");
        if (get_flag(COMPILATION_FLAG_CLEAN)) system("rm ./output");
    }

    stop_stanczyk();

    return 0;
}
