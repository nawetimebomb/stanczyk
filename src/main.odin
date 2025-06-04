
package main

import "core:c/libc"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"

COMPILER_DATE    :: "2025-03-03"
COMPILER_EXEC    :: "skc"
COMPILER_NAME    :: "Stańczyk"
COMPILER_VERSION :: "6"
COMPILER_ENV     :: "STANCZYK_DIR"

ARCH_64 :: 64
ARCH_32 :: 32

GENERATED_FILE_NAME :: "skgen.c"

Location :: struct {
    file: string,
    offset: int,
}

Source_File :: struct {
    filename: string,
    data: string,
    internal: bool,
}

compiler_dir:      string
source_files:      [dynamic]Source_File

// Switches
output_filename:      string
debug_switch_enabled: bool

// TODO: This is useful for debugging, but maybe I need an Arena allocator as the default
skc_allocator: mem.Tracking_Allocator

when ODIN_DEBUG {
    reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> (err: bool) {
        for _, value in a.allocation_map {
            fmt.printfln("{0}: Leaked {1} bytes", value.location, value.size)
            err = true
        }

        mem.tracking_allocator_clear(a)
        return
    }
}

cleanup_exit :: proc(code: int) {
    for x in source_files {
        delete(x.filename)
        delete(x.data)
    }
    delete(source_files)
    delete(compiler_dir)

    when ODIN_DEBUG {
        reset_tracking_allocator(&skc_allocator)
        mem.tracking_allocator_destroy(&skc_allocator)
    }

    os.exit(code)
}

load_file :: proc(filename: string, internal := false, dir := "") {
    parsed := filename

    if dir != "" {
        parsed = fmt.tprintf("{}/{}", dir, filename)
    }

    f, _ := os.stat(parsed, context.temp_allocator)
    data, success :=
        os.read_entire_file(f.fullpath, context.temp_allocator)

    if !success {
        fmt.println(filename, dir)
        fmt.printfln(ERROR_FILE_CANT_OPEN, f.fullpath)
        cleanup_exit(1)
    }

    append(&source_files, Source_File{
        filename = strings.clone(f.fullpath),
        data = strings.clone(string(data)),
        internal = internal,
    })
}

load_files_from_dir :: proc(dir: string) {
    v, _ := os.open(dir)
    fis, _ := os.read_dir(v, 0, context.temp_allocator)

    for f in fis {
        if strings.ends_with(f.name, ".sk") {
            load_file(f.fullpath)
        }
    }
}

Compiler_Error :: enum u8 {
    Missing_Environment = 1,
    Compiler_Dir_Undefined,
}

main :: proc() {
    setup_fatalf :: proc(e: Compiler_Error, format: string, args: ..any) {
        fmt.eprintf("compiler error: ")
        fmt.eprintfln(format, ..args)
        fmt.eprintln()
        cleanup_exit(int(e))
    }

    when ODIN_DEBUG {
        context.logger = log.create_console_logger()

        default_allocator := context.allocator
        mem.tracking_allocator_init(&skc_allocator, default_allocator)
        context.allocator = mem.tracking_allocator(&skc_allocator)
    }

    base_dir, ok := os.lookup_env(COMPILER_ENV, context.temp_allocator)
    if !ok {
        // TODO: Maybe allow the user to access some kind of command that sets the environment variable for them.
        setup_fatalf(
                .Missing_Environment,
            `'{0}' environment variable is not set
Make sure '{0}' is set and points to the directory where The {1} Compiler is installed.`,
            COMPILER_ENV, COMPILER_NAME,
        )
    }

    compiler_dir, ok = filepath.abs(base_dir)
    if !ok {
        setup_fatalf(
                .Compiler_Dir_Undefined,
            "couldn't determine compiler directory from {} (taken from the environment variable '{}')",
            base_dir, COMPILER_ENV,
        )
    }

    // load_file("builtin.sk", true, fmt.tprintf("{}/base", compiler_dir))
    load_file("runtime.sk", true, fmt.tprintf("{}/base", compiler_dir))

    bootstrap_files_count := len(source_files)

    if len(os.args) < 2 {
        fmt.println(MSG_HELP)
        cleanup_exit(0)
    }

    command := os.args[1]

    switch command {
    case "build", "run":
        if len(os.args) < 3 {
            fmt.println(MSG_HELP)
            cleanup_exit(0)
        }

        input := os.args[2]

        if !os.exists(input) {
            fmt.printfln(ERROR_FILE_OR_DIR_NOT_FOUND, input)
            cleanup_exit(1)
        }

        if strings.ends_with(input, ".sk") {
            if output_filename == "" { output_filename = filepath.short_stem(input) }
            load_file(input)
        } else {
            if output_filename == "" { output_filename = filepath.base(input) }
            load_files_from_dir(input)
        }

    case "help":
        fmt.println(MSG_HELP)
        cleanup_exit(0)
    case "version":
        fmt.printfln(MSG_VERSION, COMPILER_VERSION)
        cleanup_exit(0)
    }

    // Handle switches
    if len(os.args) > 2 {
        rest := os.args[3:]

        for i := 0; i < len(rest); i += 1 {
            v := rest[i]

            switch v {
            case "-debug":
                debug_switch_enabled = true
            case "-out":
                if len(rest) >= i + 1 {
                    i += 1
                    output_filename = rest[i]
                }
            }
        }
    }

    if len(source_files) == bootstrap_files_count {
        fmt.println(ERROR_NO_INPUT_FILE)
        cleanup_exit(1)
    }

    compile()

    libc.system(fmt.ctprintf("fasm2 {0}.asm -n", output_filename))
    libc.system(fmt.ctprintf("ld {0}.o -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2 -o {0}", output_filename))

    when !ODIN_DEBUG {
        os.remove(fmt.tprintf("{}.asm", output_filename))
        os.remove(fmt.tprintf("{}.o", output_filename))
    }

    if command == "run" {
        libc.system(fmt.ctprintf("./{}", output_filename))
        os.remove(output_filename)
        os.remove(fmt.tprintf("{}.asm", output_filename))
        os.remove(fmt.tprintf("{}.o", output_filename))
    }

    cleanup_exit(0)
}
