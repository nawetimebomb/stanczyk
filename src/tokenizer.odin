package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:reflect"
import "core:strings"

Token_Kind :: enum u8 {
    Invalid,
    Comment,
    EOF,

    Identifier,      // main

    Paren_Left,      // (
    Paren_Right,     // )
    Bracket_Left,    // [
    Bracket_Right,   // ]
    Brace_Left,      // {
    Brace_Right,     // }

    Integer,         // 123
    False,           // false
    Float,           // 1.23
    Character,       // 'a'
    String,          // "abc"
    True,            // true

    Bang,            // !
    Bang_Equal,      // !=
    Colon_Colon,     // ::
    Dash_Dash_Dash,  // ---
    Equal,           // =
    Greater,         // >
    Greater_Equal,   // >=
    Less,            // <
    Less_Equal,      // <=
    Minus,           // -
    Minus_Minus,     // --
    Percentage,      // %
    Plus,            // +
    Plus_Plus,       // ++
    Semicolon,       // ;
    Slash,           // /
    Star,            // *

    // Reserved words
    Keyword_And,     // and
    Keyword_Dup,     // dup
    Keyword_Enum,    // enum
    Keyword_If,      // if
    Keyword_Or,      // or
    Keyword_Print,   // print
    Keyword_Println, // println
    Keyword_Struct,  // struct
    Keyword_Swap,    // swap
    Keyword_Type,    // type
    Keyword_Typeof,  // typeof
    Keyword_Using,   // using

    // Types
    Type_Bool,       // bool
    Type_Float,      // float
    Type_F64,        // f64
    Type_F32,        // f32
    Type_Int,        // int
    Type_Ptr,        // ptr
    Type_S64,        // s64
    Type_S32,        // s32
    Type_S16,        // s16
    Type_S8,         // s8
    Type_String,     // string
    Type_U64,        // u64
    Type_U32,        // u32
    Type_U16,        // u16
    Type_U8,         // u8
    Type_Uint,       // uint

    Dot_Exit,        // .exit (REPL)
}

Token :: struct {
    source: string,
    file:   string,
    start:  int,
    end:    int,
    kind:   Token_Kind,
}

Tokenizer :: struct {
    filepath:         string,
    buffer:           string,
    offset:           int,
    max_offset:       int,
    whitespace_left:  bool,
    whitespace_right: bool,
}

start_tokenizer :: proc(buf: string, filepath: string) -> (result: Tokenizer) {
    result.buffer = buf
    result.filepath = filepath
    result.offset = 0
    result.max_offset = len(buf)
    result.whitespace_left = false
    result.whitespace_right = false
    return
}

tokenize :: proc(buf: string, filepath: string = "") -> (result: []Token) {
    tokenizer := start_tokenizer(buf, filepath)
    tokens := make([dynamic]Token, 0, 0, context.temp_allocator)

    for {
        token := get_next_token(&tokenizer)
        append(&tokens, token)
        if token.kind == .EOF { break }
    }

    return tokens[:]
}

@(private="file")
get_next_token :: proc(t: ^Tokenizer) -> (token: Token) {
    skip_whitespaces(t)

    token.start  = t.offset
    token.file   = t.filepath
    token.kind   = .EOF

    if is_eof(t) { return }

    if is_number(t) {
        tokenize_number(t, &token)
    } else {
        switch get_char_at(t) {
        case '!':  tokenize_bang   (t, &token)
        case '.':  tokenize_dot    (t, &token)
        case '/':  tokenize_slash  (t, &token)
        case ':':  tokenize_colon  (t, &token)
        case '<':  tokenize_less   (t, &token)
        case '>':  tokenize_greater(t, &token)
        case '-':  tokenize_minus  (t, &token)
        case '+':  tokenize_plus   (t, &token)
        case ';':  token.kind = .Semicolon;   t.offset += 1
        case '(':  token.kind = .Paren_Left;  t.offset += 1
        case ')':  token.kind = .Paren_Right; t.offset += 1
        case '%':  token.kind = .Percentage;  t.offset += 1
        case '*':  token.kind = .Star;        t.offset += 1
        case '=':  token.kind = .Equal;       t.offset += 1

        case '\'': fallthrough
        case '"':  tokenize_string_literal(t, &token)

        case    : tokenize_symbol(t, &token)
        }
    }

    token.end = t.offset
    token.source = t.buffer[token.start:token.end]

    return
}

@(private="file")
get_word_at :: #force_inline proc(t: ^Tokenizer) -> string {
    result := strings.builder_make(context.temp_allocator)

    for !is_eof(t) && !is_whitespace(t) && is_valid_word_component(t) {
        strings.write_byte(&result, get_char_at(t))
        t.offset += 1
    }

    return strings.to_string(result)
}

@(private="file")
get_char_at :: proc(t: ^Tokenizer, offset: int = 0) -> (result: byte) {
    return t.buffer[t.offset + offset]
}

@(private="file")
skip_whitespaces :: proc(t: ^Tokenizer) {
    old_offset := t.offset
    for !is_eof(t) && is_whitespace(t) { t.offset += 1 }
    t.whitespace_left = t.offset != old_offset
}

@(private="file")
temp_string :: proc(args: ..string) -> string {
    temp := strings.builder_make(context.temp_allocator)
    for s in args { strings.write_string(&temp, s) }
    return strings.to_string(temp)
}

@(private="file")
is_alpha :: #force_inline proc(t: ^Tokenizer) -> bool {
    return is_alpha_lowercase(t) || is_alpha_uppercase(t)
}

@(private="file")
is_alphanumeric :: #force_inline proc(t: ^Tokenizer) -> bool {
    return is_alpha(t) || is_number(t)
}

@(private="file")
is_alpha_lowercase :: #force_inline proc(t: ^Tokenizer) -> bool {
    c := get_char_at(t)
    return c >= 'a' && c <= 'z'
}

@(private="file")
is_alpha_uppercase :: #force_inline proc(t: ^Tokenizer) -> bool {
    c := get_char_at(t)
    return c >= 'A' && c <= 'Z'
}

@(private="file")
is_char :: #force_inline proc(t: ^Tokenizer, c: byte) -> bool {
    return get_char_at(t) == c
}

@(private="file")
is_eof :: proc(t: ^Tokenizer) -> bool {
    return t.offset >= t.max_offset
}

@(private="file")
is_newline :: #force_inline proc(t: ^Tokenizer) -> bool {
    c := get_char_at(t)
    return c == '\n'
}

@(private="file")
is_number :: #force_inline proc(t: ^Tokenizer) -> bool {
    c := get_char_at(t)
    return c >= '0' && c <= '9'
}

@(private="file")
is_valid_word_component :: #force_inline proc(t: ^Tokenizer) -> bool {
    return is_alpha(t) || is_number(t) || is_char(t, '-') || is_char(t, '_')
}

@(private="file")
is_whitespace :: proc(t: ^Tokenizer) -> bool {
    c := get_char_at(t)
    return c == ' ' || c == '\t' || c == '\r' || c == '\n'
}

@(private="file")
tokenize_bang :: proc(t: ^Tokenizer, token: ^Token) {
    token.kind = .Bang
    t.offset += 1

    if is_char(t, '=') {
        token.kind = .Bang_Equal
        t.offset += 1
    }
}

@(private="file")
tokenize_colon :: proc(t: ^Tokenizer, token: ^Token) {
    if is_eof(t) { return }
    t.offset += 1

    if is_char(t, ':') {
        token.kind = .Colon_Colon
        t.offset += 1
    } else {
        token.kind = .Invalid
    }
}

@(private="file")
tokenize_dot :: proc(t: ^Tokenizer, token: ^Token) {
    if compiler_mode != .REPL {
        token.kind = .Invalid
        return
    }

    if is_eof(t) { return }
    t.offset += 1

    // Note: In REPL-mode, some reserved words start with ".", so we need to parse them.
    if is_alpha(t) {
        word := get_word_at(t)
        full_word := temp_string(".", word)

        switch full_word {
        case ".exit": token.kind = .Dot_Exit
        case: token.kind = .Invalid
        }
    }
}

@(private="file")
tokenize_greater :: proc(t: ^Tokenizer, token: ^Token) {
    token.kind = .Greater
    t.offset += 1

    if is_char(t, '=') {
        token.kind = .Greater_Equal
        t.offset += 1
    }
}

@(private="file")
tokenize_less :: proc(t: ^Tokenizer, token: ^Token) {
    token.kind = .Less
    t.offset += 1

    if is_char(t, '=') {
        token.kind = .Less_Equal
        t.offset += 1
    }
}

@(private="file")
tokenize_minus :: proc(t: ^Tokenizer, token: ^Token) {
    token.kind = .Minus
    t.offset += 1

    if is_number(t) {
        tokenize_number(t, token)
    } else if is_char(t, '-') {
        token.kind = .Minus_Minus
        t.offset += 1

        if is_char(t, '-') {
            token.kind = .Dash_Dash_Dash
            t.offset += 1
        }
    }
}

@(private="file")
tokenize_number :: proc(t: ^Tokenizer, token: ^Token) {
    token.kind  = .Integer

    for is_number(t) || is_char(t, '.') || is_char(t, '_') {
        if is_char(t, '.') {
            token.kind = .Float
        }

        t.offset += 1
    }
}

@(private="file")
tokenize_plus :: proc(t: ^Tokenizer, token: ^Token) {
    token.kind = .Plus
    t.offset += 1

    if is_char(t, '+') {
        token.kind = .Plus_Plus
        t.offset += 1
    }
}

@(private="file")
tokenize_slash :: proc(t: ^Tokenizer, token: ^Token) {
    token.kind = .Slash
    t.offset += 1

    if is_char(t, '/') {
        // It's a comment, skip the rest of the line
        token.kind = .Comment
        for !is_eof(t) && !is_char(t, '\n') { t.offset += 1 }
    }
}

@(private="file")
tokenize_string_literal :: proc(t: ^Tokenizer, token: ^Token) {
    delimiter := get_char_at(t)

    if is_eof(t) { return }
    t.offset += 1

    token.kind = delimiter == '\'' ? .Character : .String
    is_escaped := false

    for !is_eof(t) {
        if is_char(t, delimiter) && !is_escaped { break }
        is_escaped = !is_escaped && is_char(t, '\\')
        t.offset += 1
    }

    if is_eof(t) { return }
    t.offset += 1
}

@(private="file")
tokenize_symbol :: proc(t: ^Tokenizer, token: ^Token) {
    word := get_word_at(t)

    switch word {
    case "false"   : token.kind = .False
    case "true"    : token.kind = .True

    case "and"     : token.kind = .Keyword_And
    case "dup"     : token.kind = .Keyword_Dup
    case "if"      : token.kind = .Keyword_If
    case "or"      : token.kind = .Keyword_Or
    case "print"   : token.kind = .Keyword_Print
    case "println" : token.kind = .Keyword_Println
    case "swap"    : token.kind = .Keyword_Swap
    case "type"    : token.kind = .Keyword_Type
    case "typeof"  : token.kind = .Keyword_Typeof
    case "using"   : token.kind = .Keyword_Using

    case "bool"    : token.kind = .Type_Bool
    case "float"   : token.kind = .Type_Float
    case "f64"     : token.kind = .Type_F64
    case "f32"     : token.kind = .Type_F32
    case "int"     : token.kind = .Type_Int
    case "ptr"     : token.kind = .Type_Ptr
    case "s64"     : token.kind = .Type_S64
    case "s32"     : token.kind = .Type_S32
    case "s16"     : token.kind = .Type_S16
    case "s8"      : token.kind = .Type_S8
    case "string"  : token.kind = .Type_String
    case "u64"     : token.kind = .Type_U64
    case "u32"     : token.kind = .Type_U32
    case "u16"     : token.kind = .Type_U16
    case "u8"      : token.kind = .Type_U8
    case "uint"    : token.kind = .Type_Uint

    case           : token.kind = .Identifier
    }
}
