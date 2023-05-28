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

#include "scanner.h"
#include "memory.h"
#include "fileman.h"
#include "compiler.h"
#include "util.h"
#include "common.h"

static void add_processed_file(FileArray *array,
                               const char *filename, const char *source) {
    if (array->capacity < array->count + 1) {
        int prev_capacity = array->capacity;
        array->capacity = GROW_CAPACITY(prev_capacity);
        array->filenames = GROW_ARRAY(char *, array->filenames,
                                      prev_capacity, array->capacity);
        array->sources = GROW_ARRAY(char *, array->sources,
                                    prev_capacity, array->capacity);
    }

    int filename_len = strlen(filename) + 1;
    int source_len = strlen(source) + 1;
    array->filenames[array->count] = ALLOCATE(char, filename_len);
    array->sources[array->count] = ALLOCATE(char, source_len);
    memcpy(array->filenames[array->count], filename, filename_len);
    memcpy(array->sources[array->count], source, source_len);
    array->count++;
}

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


static const char *process_source(const char *source) {
    int length = strlen(source) + 1;
    char *p = ALLOCATE(char, length);
    memset(p, 0, length);
    int i = 0;

    for (char c = *source; c;) {
        // Removing comments from source file.
        if (c == ';') {
            while (c != '\n' && c != '\0') {
                c = *++source;
            }
        }

        // Removing _ between digits, allowing 1_000_000
        if (is_digit(c)) {
            while (c != '\n' && c != ' ' && c != '\0') {
                if (c != '_') {
                    p[i] = c;
                    i++;
                    c = *++source;
                } else {
                    c = *++source;
                }
            }
        }

        p[i] = c;
        i++;
        c = *++source;
    }

    return p;
}

static char *get_word_in_name(const char *name) {
    char *result = ALLOCATE(char, 64);
    memset(result, 0, 64);
    int i = 0;

    for (char c = *name; c; c = *++name) {
        if (is_alpha(c) || is_digit(c) || is_allowed_char(c) || c == '.') {
            result[i] = c;
            i++;
        }
    }

    return result;
}

static char *get_file_path(Compiler *compiler, const char *name) {
    bool is_dev_lib = strstr(name, ".sk");
    char *filepath = ALLOCATE(char, 256);
    memset(filepath, 0, 256);

    if (is_dev_lib) {
        strcpy(filepath, compiler->options.compiler_dir);
        strcat(filepath, "/");
        strcat(filepath, get_word_in_name(name));
    } else {
        strcpy(filepath, compiler->options.compiler_dir);
        strcat(filepath, "libs/");
        strcat(filepath, get_word_in_name(name));
        strcat(filepath, ".sk");
    }

    return filepath;
}

void process_and_save(Compiler *compiler, const char *name) {
    const char *filename = get_file_path(compiler, name);
    const char *source = process_source(read_file(filename));

    add_processed_file(&compiler->files, filename, source);
}

bool library_exists(Compiler *compiler, const char *name) {
    FILE *file = fopen(get_file_path(compiler, name), "r");

    if (file) {
        fclose(file);
        return true;
    }

    return false;
}

bool library_not_processed(Compiler *compiler, const char *name) {
    const char *filename = get_file_path(compiler, name);
    int filename_len = strlen(filename);

    for (int i = 0; i < compiler->files.count; i++) {
        const char *name = compiler->files.filenames[i];
        int name_len = strlen(name);

        if (filename_len == name_len && memcmp(filename, name, filename_len) == 0) {
            return false;
        }
    }

    return true;
}
