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
#include <stdlib.h>
#include <string.h>

#include "stanczyk.h"

Stanczyk *stanczyk;

void start_stanczyk(void) {
    stanczyk = malloc(sizeof(Stanczyk));
    memset(stanczyk, 0, sizeof(Stanczyk));
}

void stop_stanczyk(void) {
    free(stanczyk);
}

const char *get_entry(void) {
    return stanczyk->workspace.entry;
}

const char *get_out(void) {
    return stanczyk->workspace.out;
}

const char *get_compiler_dir(void) {
    return stanczyk->workspace.compiler_dir;
}

const char *get_project_dir(void) {
    return stanczyk->workspace.project_dir;
}

bool get_flag(CompilationFlag flag) {
    switch (flag) {
        case COMPILATION_FLAG_CLEAN:  return stanczyk->options.clean;
        case COMPILATION_FLAG_DEBUG:  return stanczyk->options.debug;
        case COMPILATION_FLAG_RUN:    return stanczyk->options.run;
        case COMPILATION_FLAG_SILENT: return stanczyk->options.silent;
    }

    return 255;
}

bool compilation_ready(void) {
    return stanczyk->ready;
}

bool compilation_failed(void) {
    return stanczyk->result != COMPILATION_OK;
}

void set_directories(const char *compiler, const char *project) {
    stanczyk->workspace.compiler_dir = compiler;
    stanczyk->workspace.project_dir = project;
}

void set_entry(const char *entry) {
    stanczyk->workspace.entry = entry;
    stanczyk->ready = true;
}

void set_output(const char *out) {
    stanczyk->workspace.out = out;
}

void set_mode(CompilationMode mode) {
    switch (mode) {
        case COMPILATION_MODE_RUN: {
            stanczyk->options.run = true;
            stanczyk->options.clean = true;
            stanczyk->options.silent = true;
        } break;
        case COMPILATION_MODE_BUILD: {
            stanczyk->options.debug = false;
        } break;
    }
}

void set_flag(CompilationFlag flag, bool value) {
    switch (flag) {
        case COMPILATION_FLAG_CLEAN:  stanczyk->options.clean  = value; break;
        case COMPILATION_FLAG_DEBUG:  stanczyk->options.debug  = value; break;
        case COMPILATION_FLAG_RUN:    stanczyk->options.run    = value; break;
        case COMPILATION_FLAG_SILENT: stanczyk->options.silent = value; break;
    }
}
