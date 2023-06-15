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

typedef struct {
    int start;
    int capacity;
    int count;
    char **files;
    char **sources;
} FileManager;

FileManager fileman;

// TODO: Most of this code is unsafe because we never check the length of the
// input and limit it to be the expected one, so we might end with buffer
// overflow.
void init_file_manager() {
    fileman.start = 4;
    fileman.count = 0;
    fileman.capacity = 0;
    fileman.files = NULL;
    fileman.sources = NULL;
}

void free_file_manager() {
    FREE_ARRAY(char *, fileman.files, fileman.capacity);
    FREE_ARRAY(char *, fileman.sources, fileman.capacity);
    init_file_manager();
}

int get_files_count() {
    return fileman.count;
}

const char *get_file_name(int index) {
    return fileman.files[index];
}

const char *get_file_source(int index) {
    return fileman.sources[index];
}

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

static void add_processed_file(const char *filename, const char *source) {
    if (fileman.capacity < fileman.count + 1) {
        int prev_capacity = fileman.capacity;
        fileman.capacity = GROW_CAPACITY(prev_capacity, fileman.start);
        fileman.files = GROW_ARRAY(char *, fileman.files,
                                      prev_capacity, fileman.capacity);
        fileman.sources = GROW_ARRAY(char *, fileman.sources,
                                    prev_capacity, fileman.capacity);
    }

    int filename_len = strlen(filename) + 1;
    int source_len = strlen(source) + 1;
    fileman.files[fileman.count] = ALLOCATE(char, filename_len);
    memset(fileman.files[fileman.count], 0, sizeof(char) * filename_len);
    fileman.sources[fileman.count] = ALLOCATE(char, source_len);
    memset(fileman.sources[fileman.count], 0, sizeof(char) * source_len);
    memcpy(fileman.files[fileman.count], filename, filename_len);
    memcpy(fileman.sources[fileman.count], source, source_len);
    fileman.count++;
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

void process_and_save(Compiler *compiler, const char*file) {
    const char *path = get_file_path(compiler, file);
    const char *source = process_source(read_file(path));
    add_processed_file(path, source);
}

bool library_exists(Compiler *compiler, const char *file) {
    const char *path = get_file_path(compiler, file);
    if (access(path, F_OK) == -1) {
        return false;
    }

    return true;
}

bool library_not_processed(Compiler *compiler, const char *file) {
    const char *path = get_file_path(compiler, file);
    int filename_len = strlen(path);

    for (int i = 0; i < fileman.count; i++) {
        const char *name = fileman.files[i];
        int name_len = strlen(name);

        if (filename_len == name_len && memcmp(path, name, filename_len) == 0) {
            return false;
        }
    }

    return true;
}
