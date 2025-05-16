package main

import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:strings"

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

get_token_value :: proc(t: Token) -> string {
    return strings.clone(t.source)
}

run_repl :: proc() {
    should_quit := false

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

        source := sanitize_input(buf[:length])
        tokens := tokenize(source)

        for t in tokens {
            #partial switch t.kind {
                case .Dot_Exit: should_quit = true

                case .String: append(&repl_stack, get_token_value(t))

                case .Keyword_Print: {
                    v := pop(&repl_stack)
                    fmt.println(v)
                }
            }
        }

        free_all(context.temp_allocator)
    }

    cleanup_exit(0)
}
