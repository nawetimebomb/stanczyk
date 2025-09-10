package main

import "core:fmt"

Parser :: struct {
    file_info:  ^File_Info,
    errors:     [dynamic]Parser_Error,

    prev_token: Token,
    curr_token: Token,
    lexer:      Lexer,
}

Parser_Error :: struct {}

next :: proc(parser: ^Parser) -> Token {
    token := get_next_token(&parser.lexer)
    parser.prev_token = parser.curr_token
    parser.curr_token = token
    return parser.prev_token
}

parse_file :: proc(file_info: ^File_Info) {
    parser := new(Parser)

    parser.file_info = file_info

    init_lexer(parser)
    next(parser)

    for {
        token := next(parser)
        fmt.println(token)
        if token.kind == .EOF do break
    }

    free(parser)
}
