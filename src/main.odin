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
COMPILER_VERSION :: "5"

ARCH_64 :: 64
ARCH_32 :: 32

GENERATED_FILE_NAME :: "skgen.c"

Compiler_Architecture :: enum u8 {
    ARCH_64, ARCH_32,
}

Location :: struct {
    file: string,
    offset: int,
}

compiler_arch:     Compiler_Architecture
compiler_mode:     enum { Compiler, Interpreter, REPL }
source_files:      map[string]string
output_filename:   string
word_size_in_bits: int

keep_c_output := false
run_program := false

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

is_64bit :: proc() -> bool {
    return compiler_arch == .ARCH_64
}

init :: proc() {
    when ODIN_DEBUG {
        context.logger = log.create_console_logger()

        default_allocator := context.allocator
        mem.tracking_allocator_init(&skc_allocator, default_allocator)
        context.allocator = mem.tracking_allocator(&skc_allocator)
    }

    switch ODIN_ARCH {
    case .i386, .wasm32, .arm32, .Unknown:
        compiler_arch = .ARCH_32
        word_size_in_bits = 32
    case .amd64, .wasm64p32, .arm64, .riscv64:
        compiler_arch = .ARCH_64
        word_size_in_bits = 64
    }
}

cleanup_exit :: proc(code: int) {
    for key, value in source_files {
        delete(key)
        delete(value)
    }
    delete(source_files)

    when ODIN_DEBUG {
        reset_tracking_allocator(&skc_allocator)
        mem.tracking_allocator_destroy(&skc_allocator)
    }

    os.exit(code)
}

compile :: proc() {
    libc.system(fmt.ctprintf("gcc {0}.c -o {0}", output_filename))
    when !ODIN_DEBUG {
        if !keep_c_output {
            libc.system(fmt.ctprintf("rm {}.c", output_filename))
        }
    }
    if run_program { libc.system(fmt.ctprintf("./{}", output_filename)) }
}

main :: proc() {
    init()

    args := os.args[1:]

    if len(args) == 0 {
        os.exit(1)
    }

    for i := 0; i < len(args); i += 1 {
        arg := args[i]

        switch arg {
        case "-help":
            fmt.println(MSG_HELP)
            cleanup_exit(0)
        case "-version":
            fmt.printfln(MSG_VERSION, COMPILER_VERSION)
            cleanup_exit(0)
        case "-keepc":
            keep_c_output = true
        case "-run":
            run_program = true
        case "-out":
            i += 1
            output_filename = args[i]
        case :
            if !os.exists(arg) {
                fmt.printfln(ERROR_FILE_OR_DIR_NOT_FOUND, arg)
                cleanup_exit(1)
            }

            if strings.ends_with(arg, ".sk") {
                f, _ := os.stat(arg, context.temp_allocator)
                data, success :=
                    os.read_entire_file(f.fullpath, context.temp_allocator)
                output_filename = filepath.short_stem(arg)

                if !success {
                    fmt.printfln(ERROR_FILE_CANT_OPEN, f.fullpath)
                    cleanup_exit(1)
                }

                source_files[strings.clone(f.fullpath)] =
                    strings.clone(string(data))
            } else {
                v, _ := os.open(arg)
                fis, _ := os.read_dir(v, 0, context.temp_allocator)
                output_filename = filepath.base(arg)

                for f in fis {
                    if strings.ends_with(f.name, ".sk") {
                        data, success := os.read_entire_file(f.fullpath, context.temp_allocator)

                        if !success {
                            fmt.printfln(ERROR_FILE_CANT_OPEN, f.fullpath)
                            cleanup_exit(1)
                        }

                        source_files[strings.clone(f.fullpath)] = strings.clone(string(data))
                    }
                }
            }
        }
    }

    if len(source_files) == 0 {
        fmt.println(ERROR_NO_INPUT_FILE)
        cleanup_exit(1)
    }

    parse()
    compile()

    cleanup_exit(0)
}
