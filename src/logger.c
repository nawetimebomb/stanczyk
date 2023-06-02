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

#include "logger.h"
#include "stanczyk.h"

#define _RESET_     "\033[0m"
#define _BOLD_      "\033[1m"
#define _UNDERLINE_ "\033[4m"
#define _RED_       "\033[31m"

static void CLI_LOGO() {
    const char *name = "The Stańczyk Compiler";
    printf(_RED_"\n");
    puts("███████╗████████╗ █████╗ ███╗   ██╗ ██████╗███████╗██╗   ██╗██╗  ██╗\n"
         "██╔════╝╚══██╔══╝██╔══██╗████╗  ██║██╔════╝╚══███╔╝╚██╗ ██╔╝██║ ██╔╝\n"
         "███████╗   ██║   ███████║██╔██╗ ██║██║       ███╔╝  ╚████╔╝ █████╔╝ \n"
         "╚════██║   ██║   ██╔══██║██║╚██╗██║██║      ███╔╝    ╚██╔╝  ██╔═██╗ \n"
         "███████║   ██║   ██║  ██║██║ ╚████║╚██████╗███████╗   ██║   ██║  ██╗\n"
         "╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝\n");
    printf("%*s\n"_RESET_, (int)((66 + strlen(name)) / 2), name);
}

void CLI_ERROR(const char *format, ...) {
    char *message = malloc(sizeof(char) * 1024);
    memset(message, 0, sizeof(char) * 1024);

    va_list args;

    va_start(args, format);
    vsprintf(message, format, args);
    va_end(args);

    fprintf(stderr, _UNDERLINE_"ERROR:"_RESET_" %s", message);
    CLI_WELCOME();
    exit(COMPILATION_INPUT_ERROR);
}

void CLI_HELP(void) {
    // TODO: Add help message
    CLI_LOGO();

}

void CLI_WELCOME(void) {
    CLI_LOGO();
    printf(_BOLD_"Usage:\n"_RESET_"\tskc "_UNDERLINE_"command"_RESET_" [arguments]\n"
           _BOLD_"Commands:\n"_RESET_
           "\tbuild  compile the entry .sk file and it's includes.\n"
           "\trun    same as 'build', but it runs the result and cleans up the executable.\n\n"
           "For more information about what the compiler can do, you can use: skc help.\n");
    exit(COMPILATION_INPUT_ERROR);
}

void PARSING_ERROR(Token *token, const char *msg) {
    fprintf(stderr, "%s:%d:%d: " _UNDERLINE_"ERROR ",
            token->filename, token->line, token->column);

    if (TOKEN_EOF == token->type) {
        fprintf(stderr, "at end of the file");
    } else if (TOKEN_ERROR == token->type) {
        fprintf(stderr, "while lexing file");
    } else {
        fprintf(stderr, "at %.*s", token->length, token->start);
    }

    fprintf(stderr, _RESET_": %s\n", msg);
}