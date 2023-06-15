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
#ifndef STANCZYK_STANCZYK_H
#define STANCZYK_STANCZYK_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define GIT_URL "https://github.com/elnawe/stanczyk"

typedef uint8_t  u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;

typedef int8_t   s8;
typedef int16_t  s16;
typedef int32_t  s32;
typedef int64_t  s64;

typedef enum {
    COMPILATION_OK,
    COMPILATION_INPUT_ERROR,
    COMPILATION_FRONTEND_ERROR,
    COMPILATION_TYPECHECK_ERROR,
    COMPILATION_CODEGEN_ERROR,
    COMPILATION_OUTPUT_ERROR,
    COMPILATION_BACKEND_ERROR
} CompilationResult;

typedef struct {
    // workspace: List of constants used throughout the compiling
    // process to find files, check which one to compile and build the
    // executable.
    struct {
        // entry: The entry file. If a folder is given, it will be the
        // 'main.sk' on said folder.  * given by the user.
        const char *entry;

        // out: The output filename. Name is used in the assembly
        // output and the final executable.  * given by the user.
        const char *out;

        // project_dir: Folder where the entry file is. Used to look
        // up the file system when needed, i.e. #include "my/file.sk".
        // * computed by the compiler.
        const char *project_dir;

        // compiler_dir: Folder where the compiler lives. Used to look
        // up Stańczyk libraries.  i.e. #include "io" * computed by
        // the compiler.
        const char *compiler_dir;
    } workspace;

    // options: Compiler options given by the user. Change how the
    // compiler behaves or what it does during and after the
    // compilation process.
    struct {
        // clean: Removes all compilation files, like the Assembly
        // output and the Object file output.
        bool clean;

        // debug: Sets debug flags when linking to the system,
        // providing a way to debug the output through gdb and other
        // debug tools.
        bool debug;

        // run: Run the final executable. If given during a 'build'
        // compilation, runs the result.  During a 'run' compilation
        // process, the run flag is always true.
        bool run;

        // silent: Hides all the output messages from the compiler
        // (only when the compilation is success).  This includes
        // information messages and timers of compilation.
        bool silent;
    } options;

    // performance: Tracks the time it takes to complete every step.
    // Useful information to print out after the compilation process.
    struct {
        // frontend: Time it took to compile to bytecode.
        float frontend;

        // typecheck: Time it took to do the typechecking.
        float typecheck;

        // codegen: Time it took to generate code for specific platform.
        float codegen;

        // output: Time it took to generate the output file.
        float output;

        // backend: Time it took for the assembler to run and compile.
        float backend;
    } performance;

    // result: flag that marks the compilation result throughout the process.
    CompilationResult result;

    // ready: flag that marks the start of the compilation procress.
    bool ready;
} Stanczyk;

void start_stanczyk(void);
void stop_stanczyk(void);

const char *get_entry_file(void);
const char *get_compiler_dir(void);
const char *get_project_dir(void);
void set_directories(const char *, const char *);
void set_entry_file(const char *);

#endif
