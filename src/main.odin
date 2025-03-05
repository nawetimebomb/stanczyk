package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:strings"

COMPILER_DATE    :: "2025-03-03"
COMPILER_EXEC    :: "skc"
COMPILER_NAME    :: "Stańczyk"
COMPILER_VERSION :: "5"

Compiler :: struct {
    mode:       enum { Compiler, Interpreter, REPL },
    input:      [dynamic]string,
    output:     string,
    input_type: enum { directory, file },

    tokens:     [dynamic]Token,
}

skc: Compiler

// TODO: This is useful for debugging, but maybe I need an Arena allocator for default?
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

init :: proc() {
    when ODIN_DEBUG {
        context.logger = log.create_console_logger()

        default_allocator := context.allocator
        mem.tracking_allocator_init(&skc_allocator, default_allocator)
        context.allocator = mem.tracking_allocator(&skc_allocator)
    }
}

cleanup_exit :: proc(code: int) {
    for v in skc.input { delete(v) }
    delete(skc.input)

    when ODIN_DEBUG {
        reset_tracking_allocator(&skc_allocator)
        mem.tracking_allocator_destroy(&skc_allocator)
    }

    os.exit(code)
}

main :: proc() {
    init()

    args := os.args[1:]

    if len(args) == 0 {
        skc.mode = .REPL
        run_repl()
    }

    for i := 0; i < len(args); i += 1 {
        arg := args[i]

        switch arg {
        case "--help":
            fmt.println(MSG_HELP)
            cleanup_exit(0)
        case "--version":
            fmt.printfln(MSG_VERSION, COMPILER_VERSION)
            cleanup_exit(0)
        case :
            if !os.exists(arg) {
                fmt.printfln(ERROR_FILE_OR_DIR_NOT_FOUND, arg)
                cleanup_exit(1)
            }

            if strings.ends_with(arg, ".sk") {
                f, _ := os.stat(arg, context.temp_allocator)
                append(&skc.input, strings.clone(f.fullpath))
            } else {
                v, _ := os.open(arg)
                fis, _ := os.read_dir(v, 0, context.temp_allocator)

                for f in fis {
                    if strings.ends_with(f.name, ".sk") {
                        append(&skc.input, strings.clone(f.fullpath))
                    }
                }
            }
        }
    }

    if len(skc.input) == 0 {
        fmt.println(ERROR_NO_INPUT_FILE)
        cleanup_exit(1)
    }

    for filepath in skc.input {
        buf, _ := os.read_entire_file(filepath, context.temp_allocator)
        result := tokenize(string(buf), filepath)
        append(&skc.tokens, ..result)
    }

    fmt.println(skc.tokens)

    cleanup_exit(0)
}
