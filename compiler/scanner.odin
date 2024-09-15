package main

// import "core:fmt"
// import "core:os"
// import "core:strconv"
// import "core:strings"
// import "core:unicode"
// import "core:unicode/utf8"

// Scanner :: struct {
//     current_column: int,
//     current_filename: string,
//     current_line: int,
//     current_line_length: int,
//     files: [dynamic]string,
// }

// ReservedWord :: struct {
//     type: TokenType,
//     value: string,
// }

// reserved_words := []ReservedWord{
//     { type = .BLOCK_CLOSE,    value = ")",     },
//     { type = .BLOCK_OPEN,     value = "(",     },
//     { type = .CONSTANT_FALSE, value = "false", },
//     { type = .CONSTANT_TRUE,  value = "true",  },
//     { type = .FUNCTION,       value = "fn",    },
//     { type = .MINUS,          value = "-",     },
//     { type = .PERCENT,        value = "%",     },
//     { type = .PLUS,           value = "+",     },
//     { type = .PRINT,          value = "print", },
//     { type = .RETURNS,        value = "->",    },
//     { type = .SLASH,          value = "/",     },
//     { type = .STAR,           value = "*",     },
//     { type = .TYPE_ANY,       value = "any",   },
//     { type = .TYPE_BOOL,      value = "bool",  },
//     { type = .TYPE_FLOAT,     value = "float", },
//     { type = .TYPE_INT,       value = "int",   },
//     { type = .TYPE_PTR,       value = "ptr",   },
//     { type = .TYPE_STR,       value = "str",   },
// }

// scanner: Scanner

// setup_and_run_scanner :: proc() {
//     scanner.files = make([dynamic]string, 0, 4)

//     if compiler_options.entry_type_given == .FILE {
//         append(&scanner.files, compiler_options.entry)
//     } else {
//         // TODO: Support directory
//     }

//     for filename in scanner.files {
//         scanner.current_filename = filename
//         scanner.current_line = 1
//         scanner.current_column = 0

//         run_scanner_on_file(filename)
//     }

//     make_eof_token()

//     if compiler_options.show_tokens {
//         for token in program.tokens {
//             fmt.println(token)
//         }
//     }
// }

// run_scanner_on_file :: proc(filename: string) {
//     data, ok := os.read_entire_file(filename)
//     defer delete(data)

//     if !ok {
//         fmt.printfln("ERROR: Cannot read file: {0}", filename)
//         return
//     }

//     iterator := string(data)

//     for line in strings.split_lines_iterator(&iterator) {
//         scanner.current_column = 0
//         scanner.current_line_length = len(line)

//         for ;scanner.current_column < len(line); {
//             c := rune(line[scanner.current_column])

//             if c == ';' {
//                 break
//             }

//             if c == ' ' {
//                 advance()
//                 continue
//             }

//             switch {
//             case unicode.is_number(c):
//                 make_number_token(c, line)
//             case c == '"':
//                 make_string_token(c, line)
//             case:
//                 make_word_token(c, line)
//             }

//             advance()
//         }

//         scanner.current_line += 1
//     }
// }

// advance :: proc() -> bool {
//     scanner.current_column += 1

//     if scanner.current_column >= scanner.current_line_length {
//         return false
//     }

//     return true
// }

// make_word_token :: proc(c: rune, line: string) {
//     token: Token
//     result: [dynamic]rune
//     defer delete(result)

//     token.location = get_location()

//     append(&result, c)

//     for advance() {
//         new_c := rune(line[scanner.current_column])

//         if new_c == ' ' {
//             break
//         }

//         append(&result, new_c)
//     }

//     // TODO: Type should match the token value
//     val := utf8.runes_to_string(result[:])

//     for word in reserved_words {
//         if word.value == val {
//             token.type = word.type
//         }
//     }

//     if token.type == .UNKNOWN {
//         token.type = .WORD
//         token.value = val
//     }

//     append(&program.tokens, token)
// }

// make_string_token :: proc(c: rune, line: string) {
//     token: Token
//     result: [dynamic]rune
//     defer delete(result)

//     token.location = get_location()
//     token.type = .CONSTANT_STRING

//     append(&result, c)

//     for advance() {
//         new_c := rune(line[scanner.current_column])

//         append(&result, new_c)

//         if new_c == '"' {
//             break
//         }
//     }

//     token.value = utf8.runes_to_string(result[:])

//     append(&program.tokens, token)
// }

// make_number_token :: proc(c: rune, line: string) {
//     token: Token
//     result: [dynamic]rune
//     defer delete(result)

//     token.location = get_location()
//     token.type = .CONSTANT_INT

//     append(&result, c)

//     for advance() {
//         new_c := rune(line[scanner.current_column])

//         if unicode.is_number(new_c) {
//             append(&result, new_c)
//         } else if new_c == '.' {
//             append(&result, new_c)
//             token.type = .CONSTANT_FLOAT
//         } else if new_c == '_' {
//             continue
//         } else {
//             break
//         }
//     }

//     #partial switch token.type {
//     case .CONSTANT_FLOAT:
//         token.value = strconv.atof(utf8.runes_to_string(result[:]))
//     case .CONSTANT_INT:
//         token.value = strconv.atoi(utf8.runes_to_string(result[:]))
//     }

//     append(&program.tokens, token)
// }

// make_eof_token :: proc() {
//     token: Token

//     token.location = get_location()
//     token.type = .EOF

//     append(&program.tokens, token)
// }

// get_location :: proc() -> Location {
//     return Location{
//         line     = scanner.current_line,
//         column   = scanner.current_column,
//         filename = scanner.current_filename,
//     }
// }
