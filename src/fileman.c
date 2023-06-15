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
#include <unistd.h>

#include "scanner.h"
#include "memory.h"
#include "fileman.h"
#include "compiler.h"
#include "util.h"
#include "common.h"

// TODO: Most of this code is unsafe because we never check the length of the
// input and limit it to be the expected one, so we might end with buffer overflow.

static char *get_word_in_name(const char *name) {
    char *result = ALLOCATE(char, 32);
    memset(result, 0, sizeof(char) * 32);
    int i = 0;

    for (char c = *name; c; c = *++name) {
        if (is_alpha(c) || is_digit(c) || is_allowed_char(c) || c == '.' || c == '/') {
            result[i] = c;
            i++;
        }
    }

    return result;
}

static char *get_file_path(Compiler *compiler, const char *name) {
    bool is_dev_lib = strstr(name, ".sk");
    char *filepath = ALLOCATE(char, 256);
    memset(filepath, 0, sizeof(char) * 256);

    if (is_dev_lib) {
        strcpy(filepath, compiler->options.workspace);
        strcat(filepath, "/");
        strcat(filepath, get_word_in_name(name));
    } else {
        strcpy(filepath, compiler->options.compiler_dir);
        strcat(filepath, "/libs/");
        strcat(filepath, get_word_in_name(name));
        strcat(filepath, ".sk");
    }

    return filepath;
}

Filename get_full_path(Compiler *compiler, const char *name) {
    Filename result;
    result.name = get_file_path(compiler, name);
    return result;
}

static void add_processed_file(FileArray *array,
                               const char *filename, const char *source) {
    if (array->capacity < array->count + 1) {
        int prev_capacity = array->capacity;
        array->capacity = GROW_CAPACITY(prev_capacity, array->start);
        array->filenames = GROW_ARRAY(char *, array->filenames,
                                      prev_capacity, array->capacity);
        array->sources = GROW_ARRAY(char *, array->sources,
                                    prev_capacity, array->capacity);
    }

    int filename_len = strlen(filename) + 1;
    int source_len = strlen(source) + 1;
    array->filenames[array->count] = ALLOCATE(char, filename_len);
    memset(array->filenames[array->count], 0, sizeof(char) * filename_len);
    array->sources[array->count] = ALLOCATE(char, source_len);
    memset(array->sources[array->count], 0, sizeof(char) * source_len);
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

void process_and_save(Compiler *compiler, Filename *file) {
    const char *source = process_source(read_file(file->name));
    add_processed_file(&compiler->files, file->name, source);
}

bool library_exists(Filename *file) {
    if (access(file->name, F_OK) == -1) {
        return false;
    }

    return true;
}

bool library_not_processed(Compiler *compiler, Filename *file) {
    int filename_len = strlen(file->name);

    for (int i = 0; i < compiler->files.count; i++) {
        const char *name = compiler->files.filenames[i];
        int name_len = strlen(name);

        if (filename_len == name_len && memcmp(file->name, name, filename_len) == 0) {
            return false;
        }
    }

    return true;
}
