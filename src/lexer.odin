package main

import "core:fmt"
import "core:strconv"

// Lexer rules:
//    1. We check for single character tokens
//    2. If it is not an expected single char token, we try to evaluate it as a number
//    3. Finally, we check for keywords

Lexer :: struct {
    data:        string,
    fullpath:    string,
    line_starts: [dynamic]int,

    column:      int,
    line:        int,
    offset:      int,
}

Token :: struct {
    fullpath:   string,
    l0, l1:     int,
    c0, c1:     int,
    start, end: int,
    text:       string,

    kind:       Token_Kind,
}

Token_Kind :: enum u8 {
    EOF              = 0,
    Comment          = 1,

    // Basic Type Values
    Identifier       = 2,
    Integer          = 3,
    Unsigned_Integer = 4,
    Float            = 5,
    Hex              = 6,
    Binary           = 7,
    Octal            = 8,
    String           = 9,
    Char             = 10,
    True             = 11,
    False            = 12,


    // Basic Type Names
    Type_Int         = 20,
    Type_Uint        = 21,
    Type_Float       = 22,
    Type_Bool        = 23,
    Type_String      = 24,


    // Single character tokens
    Semicolon        = 40,
    Brace_Left       = 41,
    Brace_Right      = 42,
    Bracket_Left     = 43,
    Bracket_Right    = 44,
    Paren_Left       = 45,
    Paren_Right      = 46,
    Minus            = 47,
    Plus             = 48,
    Star             = 49,
    Slash            = 50,
    Percent          = 51,


    // Keywords
    Using            = 100,
    Proc             = 101,
    Dash_Dash_Dash   = 102,
    Foreign          = 150,

    // To delete
    Print            = 255,
}

init_lexer :: proc(parser: ^Parser) {
    parser.lexer.data      = parser.file_info.source
    parser.lexer.fullpath  = parser.file_info.fullpath
    parser.lexer.column    = 0
    parser.lexer.line      = 1
    parser.lexer.offset    = 0

    append(&parser.lexer.line_starts, 0)
}

destroy_lexer :: proc(parser: ^Parser) {
    delete(parser.lexer.line_starts)
}

get_next_token :: proc(l: ^Lexer) -> (token: Token) {
    advance :: proc(l: ^Lexer, stride := 1) {
        l.offset += stride
        l.column += stride
    }

    get_byte :: proc(l: ^Lexer) -> byte {
        if is_eof(l) do return 0
        return l.data[l.offset]
    }

    peek_byte :: proc(l: ^Lexer, offset_delta: int) -> byte {
        new_offset := l.offset + offset_delta
        if new_offset >= len(l.data) do return 0
        return l.data[new_offset]
    }

    fast_forward :: proc(l: ^Lexer) {
        loop: for !is_eof(l) {
            switch get_byte(l) {
            case 0, ' ', '\t', '\r', '\n', '(', ')', ';', '.': break loop
            case: advance(l)
            }
        }
    }

    is_eof :: proc(l: ^Lexer) -> bool {
        return l.offset >= len(l.data)
    }



    tokenize_directive :: proc(l: ^Lexer, token: ^Token) {
        token.kind = .Identifier
        fast_forward(l)

        switch l.data[token.start:l.offset] {
        case "#foreign": token.kind = .Foreign
        }
    }

    tokenize_number :: proc(l: ^Lexer, token: ^Token) {
        is_decimal_number_cont :: proc(l: ^Lexer) -> bool {
            b := get_byte(l)
            return b >= '0' && b <= '9' || b == '.' || b == '_'
        }

        token.kind = .Integer
        advance(l)
        if is_eof(l) do return

        switch {
        case is_decimal_number_cont(l) || get_byte(l) == '_':
            decimal_point_found := false
            scientific_notation_found := false

            decimal_loop: for !is_eof(l) && is_decimal_number_cont(l) {
                if get_byte(l) == '.' {

                    next_byte := peek_byte(l, 1)
                    if next_byte == 0 || next_byte == '.' {
                        // break if it's the range operator 'x..y' or EOF
                        break decimal_loop
                    }

                    if decimal_point_found do break decimal_loop
                    decimal_point_found = true
                } else if get_byte(l) == 'e' {
                    if scientific_notation_found || !decimal_point_found do break decimal_loop
                    scientific_notation_found = true
                }

                advance(l)
            }

            if decimal_point_found {
                token.kind = .Float
            }
        case get_byte(l) == 'x':
            token.kind = .Hex
            advance(l)
            hex_loop: for !is_eof(l) {
                b := get_byte(l)
                switch b {
                case '0'..='9', 'a'..='f', 'A'..='F', '_': advance(l)
                case: break hex_loop
                }
            }
        case get_byte(l) == 'o':
            token.kind = .Octal
            advance(l)
            octal_loop: for !is_eof(l) {
                b := get_byte(l)
                switch b {
                case '0'..='7', '_': advance(l)
                case: break octal_loop
                }
            }
        case get_byte(l) == 'b':
            token.kind = .Binary
            advance(l)
            binary_loop: for !is_eof(l) {
                b := get_byte(l)
                switch b {
                case '0', '1', '_': advance(l)
                case: break binary_loop
                }
            }
        }

        // check if it has a suffix
        switch get_byte(l) {
        case 'b':
            token.kind = .Binary
            advance(l)
        case 'f':
            token.kind = .Float
            advance(l)
        case 'i':
            token.kind = .Integer
            advance(l)
        case 'o':
            token.kind = .Octal
            advance(l)
        case 'u':
            token.kind = .Unsigned_Integer
            advance(l)
        case 'x':
            token.kind = .Hex
            advance(l)
        }
    }

    tokenize_minus :: proc(l: ^Lexer, token: ^Token) {
        token.kind = .Minus
        advance(l)
        if get_byte(l) == '-' && peek_byte(l, 1) == '-' {
            token.kind = .Dash_Dash_Dash
            advance(l, 2)
        }
    }

    tokenize_slash :: proc(l: ^Lexer, token: ^Token) {
        token.kind = .Slash
        advance(l)
        if get_byte(l) == '/' {
            // is a comment
            token.kind = .Comment
            for !is_eof(l) && get_byte(l) != '\n' do advance(l)
        }
    }

    maybe_is_a_keyword :: proc(token: ^Token) -> bool {
        kind := get_token_kind_from_string(token.text)
        if kind != .EOF {
            token.kind = kind
            return true
        }

        return false
    }



    eat_whitespace: for !is_eof(l) {
        switch get_byte(l) {
        case ' ', '\t', '\v', '\f', '\r':
            advance(l)
        case '\n':
            advance(l)
            l.line += 1
            l.column = 0
            append(&l.line_starts, l.offset)
        case:
            break eat_whitespace
        }
    }

    token.kind     = .EOF
    token.fullpath = l.fullpath
    token.c0       = l.column
    token.l0       = l.line
    token.start    = l.offset
    token.c1     = l.column
    token.l1     = l.line
    token.end    = l.offset
    if is_eof(l) do return

    switch l.data[l.offset] {
    case '0'..='9': tokenize_number(l, &token)
    case '/':       tokenize_slash(l, &token)
    case '-':       tokenize_minus(l, &token)
    case '#':       tokenize_directive(l, &token)
    case '{':       token.kind = .Brace_Left;    advance(l)
    case '}':       token.kind = .Brace_Right;   advance(l)
    case '[':       token.kind = .Bracket_Left;  advance(l)
    case ']':       token.kind = .Bracket_Right; advance(l)
    case '(':       token.kind = .Paren_Left;    advance(l)
    case ')':       token.kind = .Paren_Right;   advance(l)
    case ';':       token.kind = .Semicolon;     advance(l)
    case '+':       token.kind = .Plus;          advance(l)
    case '*':       token.kind = .Star;          advance(l)
    case '%':       token.kind = .Percent;       advance(l)
    case:
        fast_forward(l)
        token.c1     = l.column
        token.l1     = l.line
        token.end    = l.offset
        token.kind   = .Identifier
        token.text   = string(l.data[token.start:token.end])

        maybe_is_a_keyword(&token)
    }

    token.c1     = l.column
    token.l1     = l.line
    token.end    = l.offset
    token.text   = string(l.data[token.start:token.end])

    return
}

get_token_kind_from_string :: proc(s: string) -> (Token_Kind) {
    switch s {
    case "false":  return .False
    case "true":   return .True

    case "bool":   return .Type_Bool
    case "float":  return .Type_Float
    case "int":    return .Type_Int
    case "string": return .Type_String
    case "uint":   return .Type_Uint

    case "proc":   return .Proc
    case "using":  return .Using

    case "print":  return .Print
    }

    return .EOF
}
