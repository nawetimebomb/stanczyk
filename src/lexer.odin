package main

import "core:fmt"
import "core:path/filepath"
import "core:strconv"

// Lexer rules:
//    1. We check for single character tokens
//    2. If it is not an expected single char token, we try to evaluate it as a number
//    3. Finally, we check for keywords

Lexer :: struct {
    data:        string,
    filename:    string,
    fullpath:    string,
    file_info:   ^File_Info,

    column:      int,
    line:        int,
    offset:      int,
}

Token :: struct {
    file_info:  ^File_Info,
    l0, l1:     int,
    c0, c1:     int,
    start, end: int,
    text:       string,

    kind:       Token_Kind,
}

Token_Kind :: enum u8 {
    Invalid          =   0,
    EOF              =   1,

    // Basic Type Values
    Identifier       =  10,
    Integer          =  11,
    Unsigned_Integer =  12,
    Float            =  13,
    Hex              =  14,
    Binary           =  15,
    Octal            =  16,
    String           =  17,
    Byte             =  18,
    True             =  19,
    False            =  20,


    // Single(ish) character tokens
    Semicolon        =  30,
    Brace_Left       =  31,
    Brace_Right      =  32,
    Bracket_Left     =  33,
    Bracket_Right    =  34,
    Paren_Left       =  35,
    Paren_Right      =  36,
    Minus            =  37,
    Plus             =  38,
    Star             =  39,
    Slash            =  40,
    Percent          =  41,
    Colon            =  42,
    Dash_Dash_Dash   =  50,
    Equal            =  51,
    Not_Equal        =  52,
    Greater          =  53,
    Greater_Equal    =  54,
    Less             =  55,
    Less_Equal       =  56,


    // Intrinsics
    Drop             =  60,
    Nip              =  61,
    Dup              =  62,
    Dup_Star         =  63,
    Swap             =  64,
    Rot              =  65,
    Rot_Star         =  66,
    Over             =  67,
    Tuck             =  68,


    // Keywords
    Using            = 100,
    Foreign          = 101,
    Proc             = 120,
    Type             = 121,
    Const            = 122,
    Let              = 123,
    Var              = 124,
    Set              = 125,

    Cast             = 149,
    Print            = 150,
}

init_lexer :: proc() {
    file_info := compiler.parser.file_info
    lexer := Lexer{}

    lexer.file_info = file_info
    lexer.data      = file_info.source
    lexer.filename  = filepath.short_stem(file_info.filename)
    lexer.fullpath  = file_info.fullpath
    lexer.column    = 0
    lexer.line      = 1
    lexer.offset    = 0

    compiler.parser.lexer = lexer

    append(&file_info.line_starts, 0)
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
            case 0, ' ', '\t', '\r', '\n', '(', ')', ':', ';', '.': break loop
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

    tokenize_identifier :: proc(l: ^Lexer, token: ^Token) {
        fast_forward(l)
        token.c1     = l.column
        token.l1     = l.line
        token.end    = l.offset
        token.kind   = .Identifier
        token.text   = string(l.data[token.start:token.end])

        kind := get_token_kind_from_string(token.text)
        if kind != .Invalid {
            token.kind = kind
        }
    }



    eat_whitespace: for !is_eof(l) {
        switch get_byte(l) {
        case ' ', '\t', '\v', '\f', '\r':
            advance(l)
        case '\n':
            advance(l)
            l.line += 1
            l.column = 0
            append(&l.file_info.line_starts, l.offset)
        case:
            break eat_whitespace
        }
    }

    token.kind      = .EOF
    token.file_info = l.file_info
    token.c0        = l.column
    token.l0        = l.line
    token.start     = l.offset
    token.c1        = l.column
    token.l1        = l.line
    token.end       = l.offset
    if is_eof(l) do return

    switch l.data[l.offset] {
    case '0'..='9': tokenize_number(l, &token)
    case '/':
        token.kind = .Slash
        advance(l)
        if get_byte(l) == '/' {
            for !is_eof(l) && get_byte(l) != '\n' do advance(l)
            return get_next_token(l)
        }
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
    case ':':       token.kind = .Colon;         advance(l)
    case '=':       token.kind = .Equal;         advance(l)
    case '!':
        advance(l)
        if get_byte(l) == '=' {
            token.kind = .Not_Equal
            advance(l)
        } else {
            tokenize_identifier(l, &token)
        }
    case '>':
        token.kind = .Greater
        advance(l)
        if get_byte(l) == '=' {
            token.kind = .Greater_Equal
            advance(l)
        }
    case '<':
        token.kind = .Less
        advance(l)
        if get_byte(l) == '=' {
            token.kind = .Less_Equal
            advance(l)
        }
    case '-':
        token.kind = .Minus
        advance(l)
        if get_byte(l) == '-' && peek_byte(l, 1) == '-' {
            token.kind = .Dash_Dash_Dash
            advance(l, 2)
        }
    case '\'':
        escape_found := false
        token.kind = .Byte
        advance(l)
        for !is_eof(l) {
            if get_byte(l) == '\'' && !escape_found {
                break
            }
            escape_found = !escape_found && get_byte(l) == '\\'
            advance(l)
        }

        advance(l)
    case '"':
        escape_found := false
        token.kind = .String
        advance(l)
        for !is_eof(l) {
            if get_byte(l) == '"' && !escape_found {
                break
            }
            escape_found = !escape_found && get_byte(l) == '\\'
            advance(l)
        }

        advance(l)
    case:
        tokenize_identifier(l, &token)
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

    case "drop":   return .Drop
    case "nip":    return .Nip
    case "dup":    return .Dup
    case "dup*":   return .Dup_Star
    case "swap":   return .Swap
    case "rot":    return .Rot
    case "rot*":   return .Rot_Star
    case "over":   return .Over
    case "tuck":   return .Tuck

    case "using":  return .Using

    case "proc":   return .Proc
    case "type":   return .Type
    case "const":  return .Const
    case "let":    return .Let
    case "var":    return .Var
    case "set":    return .Set

    case "cast":   return .Cast
    case "print":  return .Print
    }

    return .Invalid
}
