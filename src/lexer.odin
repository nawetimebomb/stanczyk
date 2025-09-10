package main

import "core:fmt"
import "core:strconv"

// Lexer rules:
//    1. We check for single character tokens
//    2. If it is not an expected single char token, we try to evaluate it as a number
//    3. Finally, we check for keywords

Lexer :: struct {
    data:     string,
    fullpath: string,

    column:   int,
    line:     int,
    offset:   int,
}

Token :: struct {
    fullpath:   string,
    l0, l1:     int,
    c0, c1:     int,
    start, end: int,
    text:       string,

    kind:     Token_Kind,
    value:    Token_Value,
}

Token_Kind :: enum {
    EOF              = 0,

    Identifier       = 1,
    Integer          = 2,
    Unsigned_Integer = 3,
    Float            = 4,
    String           = 5,
    Char             = 6,
    True             = 7,
    False            = 8,

    Semicolon        = 10,
    Brace_Left       = 11,
    Brace_Right      = 12,
    Bracket_Left     = 13,
    Bracket_Right    = 14,
    Paren_Left       = 15,
    Paren_Right      = 16,

    Using            = 100,
}

Token_Value :: union {
    int,
    string,
    f64,
}

init_lexer :: proc(parser: ^Parser) {
    parser.lexer.data     = parser.file_info.source
    parser.lexer.fullpath = parser.file_info.fullpath
    parser.lexer.column   = 0
    parser.lexer.line     = 1
    parser.lexer.offset   = 0
}

get_next_token :: proc(l: ^Lexer) -> (token: Token) {
    advance :: proc(l: ^Lexer) {
        l.offset += 1
        l.column += 1
        if is_eof(l) do return
        if l.data[l.offset] == '\n' {
            l.column = -1
            l.line  += 1
        }
    }

    eat_whitespace :: proc(l: ^Lexer) {
        for !is_eof(l) && is_space(l) do advance(l)
    }

    forward_word :: proc(l: ^Lexer) {
        for !is_eof(l) && !is_space(l) && !is_word_break(l) {
            advance(l)
        }
    }

    is_eof :: proc(l: ^Lexer) -> bool {
        return l.offset >= len(l.data)
    }

    is_space :: proc(l: ^Lexer) -> bool {
        b := l.data[l.offset]
        return b == ' ' || b == '\t' || b == '\r' || b == '\n'
    }

    is_word_break :: proc(l: ^Lexer) -> bool {
        b := l.data[l.offset]
        return b == '(' || b == ')' || b == ';'
    }

    maybe_is_a_number :: proc(token: ^Token) -> bool {
        if len(token.text) > 1 {
            first_part := token.text[:len(token.text) - 1]
            last_part := token.text[len(token.text) - 1]
            value, maybe_int := strconv.parse_int(first_part)
            if maybe_int do token.value = value

            // Maybe differenciate these
            switch {
            case last_part == 'b' && maybe_int:
                token.text = first_part
                token.kind = .Integer
                return true
            case last_part == 'f' && maybe_int:
                token.text = first_part
                token.kind = .Integer
                return true
            case last_part == 'i' && maybe_int:
                token.text = first_part
                token.kind = .Integer
                return true
            case last_part == 'o' && maybe_int:
                token.text = first_part
                token.kind = .Integer
                return true
            case last_part == 'u' && maybe_int:
                token.text = first_part
                token.kind = .Unsigned_Integer
                return true
            case last_part == 'x' && maybe_int:
                token.text = first_part
                token.kind = .Integer
                return true
            }
        }

        if value, ok := strconv.parse_int(token.text); ok {
            token.kind = .Integer
            token.value = value

            //if len(token.text) > 1 {
            //    switch token.text[1] {
            //    case 'b': token.kind = .Integer
            //    case 'o': token.kind = .Integer
            //    case 'x': token.kind = .Integer
            //    }
            //}

            return true
        }

        if value, ok := strconv.parse_f64(token.text); ok {
            token.kind = .Float
            token.value = value
            return true
        }

        return false
    }

    maybe_is_a_keyword :: proc(token: ^Token) -> bool {
        kind, ok := get_token_kind_from_string(token.text)
        if ok do token.kind = kind
        return ok
    }



    eat_whitespace(l)

    token.kind     = .EOF
    token.fullpath = l.fullpath
    token.c0       = l.column
    token.l0       = l.line
    token.start    = l.offset
    if is_eof(l) do return

    switch l.data[l.offset] {
    case '{': token.kind = .Brace_Left
    case '}': token.kind = .Brace_Right
    case '[': token.kind = .Bracket_Left
    case ']': token.kind = .Bracket_Right
    case '(': token.kind = .Paren_Left
    case ')': token.kind = .Paren_Right
    case ';': token.kind = .Semicolon
    case:
        forward_word(l)
        token.c1     = l.column
        token.l1     = l.line
        token.end    = l.offset
        token.kind = .Identifier
        token.text = string(l.data[token.start:token.end])

        if maybe_is_a_number(&token) do return
        if maybe_is_a_keyword(&token) do return

        return
    }


    advance(l)
    token.c1     = l.column
    token.l1     = l.line
    token.end    = l.offset
    token.text   = string(l.data[token.start:token.end])

    return
}

get_token_kind_from_string :: proc(s: string) -> (Token_Kind, bool) {
    switch s {
    case "using": return .Using, true
    }

    return .EOF, false
}
