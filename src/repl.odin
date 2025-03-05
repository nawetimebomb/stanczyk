package main

import "core:c/libc"
import "core:fmt"
import "core:os"

REPL_Value :: union {
    string,
}

@(private="file")
repl_stack: [dynamic]REPL_Value

sanitize_input :: proc(input: []byte) -> (output: string) {
    sanitized := make([dynamic]byte, 0, len(input), context.temp_allocator)

    for b in input {
        if b != '\r' && b != '\n' {
            append(&sanitized, b)
        }
    }

    output = string(sanitized[:])
    return
}

run_repl :: proc() {
    should_quit := false

    libc.system("cls")

    fmt.printfln("Stanczyk REPL version {0}", COMPILER_VERSION)
    fmt.println("type \".exit\" or press Ctrl-C to exit the Stanczyk REPL")

    buf: [256]byte

    for !should_quit {
        fmt.print("> ")
        length, err := os.read(os.stdin, buf[:])

        if err != nil {
            fmt.eprintln(ERROR_REPL, err)
            should_quit = true
        }

        input := sanitize_input(buf[:length])
        tokens := tokenize(input)

        for t in tokens {
            #partial switch t.kind {
                case .Dot_Exit: should_quit = true

                case .String: append(&repl_stack, t.value)

                // Native Functions
                case .Print:
                v := pop(&repl_stack)
                fmt.println(v)
            }
        }
    }

    cleanup_exit(0)
}
