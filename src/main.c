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

CompilerOptions options;

static char *read_file(const char *path) {
    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        fprintf(stderr, "could not open file \"%s\".\n", path);
        exit(74);
    }

    fseek(file, 0L, SEEK_END);
    size_t file_size = ftell(file);
    rewind(file);

    char *buffer = (char *)malloc(file_size + 1);
    if (buffer == NULL) {
        fprintf(stderr, "not enough memory to read \"%s\".\n", path);
        exit(74);
    }

    size_t bytes_read = fread(buffer, sizeof(char), file_size, file);
    if (bytes_read < file_size) {
        fprintf(stderr, "could not read file \"%s\".\n", path);
        exit(74);
    }

    buffer[bytes_read] = '\0';

    fclose(file);
    return buffer;
}

static char *get_file_directory(const char *path) {
    int len = strlen(path);
    char *dir = malloc(len + 1);
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

static char *get_workspace(const char *path) {
    char *result = malloc(1024);
    getcwd(result, 1024);
    strcat(result, "/");
    strcat(result, get_file_directory(path));

    return result;
}

static int load_file(const char *path) {
    char *source = read_file(path);
    // chdir(get_workspace(path));
    options.workspace = get_workspace(path);

    CompilerResult result = compile(source);
    free(source);

    return result;
}

static void parse_arguments(int argc, const char **argv) {
    for (int i = 1; i < argc; i++) {
        const char *input = argv[i];

        if ((strcmp(input, "-r") == 0) || (strcmp(input, "-run") == 0)) {
            options.run = true;
        } else if ((strcmp(input, "-d") == 0) || (strcmp(input, "-debug") == 0)) {
            options.debug = true;
        } else if ((strcmp(input, "-o") == 0) || (strcmp(input, "-out") == 0)) {
            i++;
            options.out_file = argv[i];
        } else if ((strcmp(input, "-h") == 0) || (strcmp(input, "-help") == 0)) {
            print_help();
            exit(0);
        } else if (strstr(input, ".sk")) {
            options.entry_file = input;
        } else {
            print_cli_error();
        }
    }
}

int main(int argc, const char **argv) {
    if (argc < 2) {
        print_cli_error();
    }

    parse_arguments(argc, argv);

    int result = load_file(options.entry_file);

    return result;
}
