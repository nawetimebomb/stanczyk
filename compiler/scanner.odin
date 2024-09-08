package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"

Scanner :: struct {
    current_column: int,
    current_filename: string,
    current_line: int,
    current_line_length: int,
    files: [dynamic]string,
    tokens: [dynamic]Token,
}

Token :: struct {
    location: Location,
    type: TokenType,
    value: TokenValue,
}

Location :: struct {
    column: int,
    filename: string,
    line: int,
}

TokenType :: enum {
    UNKNOWN,

    // Custom
    WORD,

    // Reserved
    BLOCK_CLOSE,
    BLOCK_OPEN,
    FUNCTION,
    MINUS,
    PLUS,
    SLASH,
    STAR,

    // System
    EOF,

    // Primitives
    FLOAT,
    INT,
    STRING,
}

TokenValue :: union {
    f64,
    i64,
    string,
}

ReservedWord :: struct {
    type: TokenType,
    value: string,
}

reserved_words := []ReservedWord{
    { type = .BLOCK_CLOSE, value = ".",  },
    { type = .BLOCK_OPEN,  value = "do", },
    { type = .FUNCTION,    value = "fn", },
    { type = .MINUS,       value = "-",  },
    { type = .PLUS,        value = "+",  },
    { type = .SLASH,       value = "/",  },
    { type = .STAR,        value = "*",  },
}

scanner: Scanner

setup_and_run_scanner :: proc() {
    scanner.files = make([dynamic]string, 0, 4)
    scanner.tokens = make([dynamic]Token, 0, 16)

    if compiler_args.entry_type_given == .FILE {
        append(&scanner.files, compiler_args.entry)
    } else {
        // TODO: Support directory
    }

    for filename in scanner.files {
        scanner.current_filename = filename
        scanner.current_line = 1
        scanner.current_column = 0

        run_scanner_on_file(filename)
    }

    for token in scanner.tokens {
        fmt.println(token)
    }
}

run_scanner_on_file :: proc(filename: string) {
    data, ok := os.read_entire_file(filename)
    defer delete(data)

    if !ok {
        fmt.printfln("ERROR: Cannot read file: {0}", filename)
        return
    }

    iterator := string(data)

    for line in strings.split_lines_iterator(&iterator) {
        scanner.current_column = 0
        scanner.current_line_length = len(line)

        for ;scanner.current_column < len(line); {
            c := rune(line[scanner.current_column])

            if c == ';' {
                break
            }

            if c == ' ' {
                advance()
                continue
            }

            switch {
            case unicode.is_number(c):
                make_number_token(c, line)
            case c == '"':
                make_string_token(c, line)
            case:
                make_word_token(c, line)
            }

            advance()
        }

        scanner.current_line += 1
    }

    make_eof_token()
}

advance :: proc() -> bool {
    scanner.current_column += 1

    if scanner.current_column >= scanner.current_line_length {
        return false
    }

    return true
}

make_word_token :: proc(c: rune, line: string) {
    token: Token
    result: [dynamic]rune
    defer delete(result)

    token.location = get_location()

    append(&result, c)

    for advance() {
        new_c := rune(line[scanner.current_column])

        if new_c == ' ' {
            break
        }

        append(&result, new_c)
    }

    // TODO: Type should match the token value
    val := utf8.runes_to_string(result[:])

    for word in reserved_words {
        if word.value == val {
            token.type = word.type
        }
    }

    if token.type == .UNKNOWN {
        token.type = .WORD
        token.value = val
    }

    append(&scanner.tokens, token)
}

make_string_token :: proc(c: rune, line: string) {
    token: Token
    result: [dynamic]rune
    defer delete(result)

    token.location = get_location()
    token.type = .STRING

    append(&result, c)

    for advance() {
        new_c := rune(line[scanner.current_column])

        append(&result, new_c)

        if new_c == '"' {
            break
        }
    }

    token.value = utf8.runes_to_string(result[:])

    append(&scanner.tokens, token)
}

make_number_token :: proc(c: rune, line: string) {
    token: Token
    result: [dynamic]rune
    defer delete(result)

    token.location = get_location()
    token.type = .INT

    append(&result, c)

    for advance() {
        new_c := rune(line[scanner.current_column])

        if unicode.is_number(new_c) {
            append(&result, new_c)
        } else if new_c == '.' {
            append(&result, new_c)
            token.type = .FLOAT
        } else if new_c == '_' {
            continue
        } else {
            break
        }
    }

    // TODO: Support FLOAT type
    #partial switch token.type {
    case .FLOAT:
        token.value = strconv.atof(utf8.runes_to_string(result[:]))
    case .INT:
        token.value = i64(strconv.atoi(utf8.runes_to_string(result[:])))
    }

    append(&scanner.tokens, token)
}

make_eof_token :: proc() {
    token: Token

    token.location = get_location()
    token.type = .EOF

    append(&scanner.tokens, token)
}

get_location :: proc() -> Location {
    return Location{
        line     = scanner.current_line,
        column   = scanner.current_column,
        filename = scanner.current_filename,
    }
}
