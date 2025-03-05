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

    Identifier,    // main
    Integer,       // 123
    Float,         // 1.23
    Character,     // 'a'
    String,        // "abc"

    Colon_Colon,   // ::
    Minus,         // -
    Paren_Left,    // (
    Paren_Right,   // )
    Plus,          // +
    Semicolon,     // ;
    Slash,         // /
    Star,          // *

    // Reserved words
    Keyword_Asm,   // ASM
    Keyword_Print, // print
    Keyword_Using, // using

    Dot_Exit,      // exit (REPL)
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

get_next_token :: proc(t: ^Tokenizer) -> (token: Token) {
    skip_whitespaces(t)

    token.start  = t.offset
    token.file   = t.filepath
    token.kind   = .EOF

    if is_eof(t) { return }

    if is_alpha(t) || is_char(t, '_') {
        parse_identifier(t, &token)
    } else if is_number(t) {
        parse_number(t, &token)
    } else {
        switch get_char_at(t) {
        case '.':  parse_dot  (t, &token)
        case ':':  parse_colon(t, &token)
        case '/':  parse_slash(t, &token)

        case '\'': fallthrough
        case '"':  parse_string_literal(t, &token)

        case ';':  token.kind = .Semicolon;   t.offset += 1
        case '(':  token.kind = .Paren_Left;  t.offset += 1
        case ')':  token.kind = .Paren_Right; t.offset += 1
        case '+':  token.kind = .Plus;        t.offset += 1
        case '-':  token.kind = .Minus;       t.offset += 1
        case '*':  token.kind = .Star;        t.offset += 1

        case:  token.kind = .Invalid; t.offset += 1
        }
    }

    token.end = t.offset
    token.source = t.buffer[token.start:token.end]

    return
}

get_word_at :: #force_inline proc(t: ^Tokenizer) -> string {
    result := strings.builder_make(context.temp_allocator)

    for !is_eof(t) && is_valid_word_component(t) {
        strings.write_byte(&result, get_char_at(t))
        t.offset += 1
    }

    return strings.to_string(result)
}

get_char_at :: proc(t: ^Tokenizer, offset: int = 0) -> (result: byte) {
    return t.buffer[t.offset + offset]
}

skip_whitespaces :: proc(t: ^Tokenizer) {
    old_offset := t.offset
    for !is_eof(t) && is_whitespace(t) { t.offset += 1 }
    t.whitespace_left = t.offset != old_offset
}

temp_string :: proc(args: ..string) -> string {
    temp := strings.builder_make(context.temp_allocator)
    for s in args { strings.write_string(&temp, s) }
    return strings.to_string(temp)
}

is_alpha :: #force_inline proc(t: ^Tokenizer) -> bool {
    return is_alpha_lowercase(t) || is_alpha_uppercase(t)
}

is_alphanumeric :: #force_inline proc(t: ^Tokenizer) -> bool {
    return is_alpha(t) || is_number(t)
}

is_alpha_lowercase :: #force_inline proc(t: ^Tokenizer) -> bool {
    c := get_char_at(t)
    return c >= 'a' && c <= 'z'
}

is_alpha_uppercase :: #force_inline proc(t: ^Tokenizer) -> bool {
    c := get_char_at(t)
    return c >= 'A' && c <= 'Z'
}

is_char :: #force_inline proc(t: ^Tokenizer, c: byte) -> bool {
    return get_char_at(t) == c
}

is_eof :: proc(t: ^Tokenizer) -> bool {
    return t.offset >= t.max_offset
}

is_newline :: #force_inline proc(t: ^Tokenizer) -> bool {
    c := get_char_at(t)
    return c == '\n'
}

is_number :: #force_inline proc(t: ^Tokenizer) -> bool {
    c := get_char_at(t)
    return c >= '0' && c <= '9'
}

is_valid_word_component :: #force_inline proc(t: ^Tokenizer) -> bool {
    return is_alpha(t) || is_number(t) || is_char(t, '_')
}

is_whitespace :: proc(t: ^Tokenizer) -> bool {
    c := get_char_at(t)
    return c == ' ' || c == '\t' || c == '\r' || c == '\n'
}

parse_colon :: proc(t: ^Tokenizer, token: ^Token) {
    if is_eof(t) { return }
    t.offset += 1

    if is_char(t, ':') {
        token.kind = .Colon_Colon
        t.offset += 1
    } else {
        token.kind = .Invalid
    }
}

parse_dot :: proc(t: ^Tokenizer, token: ^Token) {
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

parse_identifier :: proc(t: ^Tokenizer, token: ^Token) {
    word := get_word_at(t)
    test_word := strings.to_pascal_case(word, context.temp_allocator)

    switch word {
    case "ASM":   token.kind = .Keyword_Asm
    case "print": token.kind = .Keyword_Print
    case "using": token.kind = .Keyword_Using

    }

    if v, ok := reflect.enum_from_name(Token_Kind, test_word); ok {
        token.kind = v
    } else {
        token.kind  = .Identifier
    }
}

parse_number :: proc(t: ^Tokenizer, token: ^Token) {
    token.kind  = .Integer
}

parse_slash :: proc(t: ^Tokenizer, token: ^Token) {
    token.kind = .Slash

    if get_char_at(t, 1) == '/' {
        // It's a comment, skip the rest of the line
        token.kind = .Comment
        for !is_eof(t) && !is_char(t, '\n') { t.offset += 1 }
        t.offset += 1
    }
}

parse_string_literal :: proc(t: ^Tokenizer, token: ^Token) {
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
