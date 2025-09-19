package main

import "core:fmt"
import "core:os/os2"
import "core:strings"

// Parser Errors
CONST_BOOL_NO_MULTI_VALUE :: "Boolean constant declaration cannot have multiple values."

CONST_MISMATCHED_TYPES :: "Mismatched types in const declaration '{}' vs '{}'."

FAILED_TO_PARSE_TYPE :: "Failed to parse this as a valid type"

IMPERATIVE_EXPR_GLOBAL :: "Attemp to use an imperative expression while in global scope."

INVALID_BYTE_LITERAL :: "Invalid byte literal {}."

INVALID_CONST_VALUE :: "This is not a valid constant value."

INVALID_TOKEN :: "We found an invalid token '{}'. This might just be a compiler bug, please report at " + GIT_URL + "."

MAIN_PROC_TYPE_NOT_EMPTY :: "Entry point procedure must have no arguments."

UNEXPECTED_TOKEN_PROC_TYPE :: "'{}' is not a type."

UNEXPECTED_TOKEN_LET_BIND :: "'{}' is not an identifier."

// Checker Errors
MISMATCHED_NUMBER_ARGS :: "Not enough values to call '{}'; Expected {}, but got {}."

MISMATCHED_TYPES_ARG :: "Mismatched type to call '{}'; Expected '{}', but got '{}'."

MISMATCHED_NUMBER_RESULTS :: "Expected {} result(s) in procedure '{}', but got {} instead."

MISMATCHED_TYPES_BINARY_EXPR :: "Mismatched types in binary expression '{}' vs '{}'."

MISMATCHED_TYPES_RESULT :: "Mismatched types in procedure '{}' results; Expected '{}', but got '{}' instead."

MODULO_ONLY_INT :: "Modulo operator '%%' can only be used while operating with 'int'. Used '{}'."

STACK_EMPTY :: "There are not enough stack values to make this operation."

STACK_EMPTY_EXPECT :: "There are not enough stack values to make this operation. Expected {}, but got {} instead."

UNDEFINED_IDENTIFIER :: "We could not find the meaning of identifier '{}'."

// Entity Errors
REDECLARATION_FOUND :: "Redeclaration of '{}' not allowed in this scope."

REDECLARATION_OF_MAIN :: "A symbol named 'main' was already declared at {}({}:{})."

Fatal_Error_Kind :: enum u8 {
    None      = 0,
    Compiler  = 1,
    Parser    = 2,
    Checker   = 3,
    Generator = 4,
}

Compiler_Error :: struct {
    message:     string,
    token:       Token,
}

CYAN       :: "\e[0;96m"
CYAN_BOLD  :: "\e[1;96m"
RED        :: "\e[1;91m"
RESET      :: "\e[0m"

print_cyan :: proc(format: string, args: ..any) {
    message := fmt.tprintf(format, ..args)
    fmt.printf("\e[0;96m{}\e[0m", message)
}

error_red :: proc(format: string, args: ..any) {
    message := fmt.tprintf(format, ..args)
    fmt.eprintf("\e[1;91m{}\e[0m", message)
}

fatalf :: proc(error: Fatal_Error_Kind, format: string, args: ..any) {
    if !switch_silent {
        fmt.eprintln()
        error_red("{} Error: ", error)
        fmt.eprintfln(format, ..args)
        fmt.eprintln()
    }
    os2.exit(int(error))
}

report_all_errors :: proc() {
    if switch_silent {
        return
    }

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
        text := source[start:token.end]

        fmt.eprint(CYAN)
        fmt.eprintf("\t{} | \t", line_number_to_string(line_index + 1))
        for r, index in text {
            offset := index + start
            if error.token.start <= offset && offset <= error.token.end {
                fmt.eprint(RED)
            } else {
                fmt.eprint(CYAN)
            }

            fmt.eprint(r)

            if r == '\n' {
                line_index += 1
                fmt.eprintf("\t{} | \t", line_number_to_string(line_index + 1))
            }
        }

        fmt.eprint("\e[0m\n")
    }
}
