package main

import "core:fmt"
import "core:os/os2"
import "core:strings"

Fatal_Error_Kind :: enum u8 {
    None      = 0,
    Compiler  = 1,
    Parser    = 2,
    Checker   = 3,
    Generator = 4,
}

Compiler_Error :: struct {
    message: string,
    token:   Token,
}

CYAN  :: "\e[0;96m"
RED   :: "\e[1;91m"
RESET :: "\e[0m"

print_cyan :: proc(format: string, args: ..any) {
    message := fmt.tprintf(format, ..args)
    fmt.printf("\e[0;96m{}\e[0m", message)
}

error_red :: proc(format: string, args: ..any) {
    message := fmt.tprintf(format, ..args)
    fmt.eprintf("\e[1;91m{}\e[0m", message)
}

fatalf :: proc(error: Fatal_Error_Kind, format: string, args: ..any) {
    fmt.eprintln()
    error_red("{} Error: ", error)
    fmt.eprintfln(format, ..args)
    fmt.eprintln()
    os2.exit(int(error))
}

report_all_errors :: proc() {
    line_number_to_string :: proc(number: int) -> string {
        number_str := fmt.tprintf("{}", number)
        return strings.right_justify(number_str, 4, " ")
    }

    for error in compiler.errors {
        token := error.token
        fullpath := token.file_info.fullpath
        line_starts := token.file_info.line_starts
        source := token.file_info.source

        fmt.eprintfln(
            "\e[1m{}({}:{})\e[1;91m Error:\e[0m {}",
            fullpath, token.l0, token.c0, error.message,
        )
        fmt.eprint("\e[0;96m")
        if token.l0 > 1 {
            line_index := max(token.l0-2, 0)
            count_of_chars := 0
            for line_index > 0 && count_of_chars == 0 {
                start := line_starts[line_index]
                end := line_starts[line_index+1] - 1
                count_of_chars = end - start
                if count_of_chars == 0 do line_index -= 1
            }
            line_index = max(line_index, 0)
            start := line_starts[line_index]
            text := source[start:token.start]
            token_start_index := token.start - start

            fmt.eprintf("\t{} | \t", line_number_to_string(line_index + 1))
            for r, index in text {
                fmt.eprint(r)

                if r == '\n' {
                    line_index += 1
                    fmt.eprintf("\t{} | \t", line_number_to_string(line_index + 1))
                }
            }

            error_red(source[token.start:token.end])
        } else {
            curr_line := source[:token.start]
            fmt.eprintf("\t{} | \t{}", line_number_to_string(token.l0), curr_line)
            error_red(source[token.start:token.end])
        }

        fmt.eprint("\e[0m\n")
    }
}
