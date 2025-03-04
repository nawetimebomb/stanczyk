package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"

Token_Kind :: enum {
    invalid,
    eof,
    newline,

    identifier,       // main
    integer,          // 123
    float,            // 1.23
    character,        // 'a'
    string,           // "abc"

    binary_operator,  // +, -, *, /
}

Token_Operation :: enum {
    none,

    minus,
    plus,
    slash,
    star,
}

Token :: struct {
    file:      string,
    column:    int,
    line:      int,
    offset:    int,
    kind:      Token_Kind,
    operation: Token_Operation,
    value:     string,
}

Tokenizer :: struct {
    is_last_file:     bool,
    file_index:       int,
    line_count:       int,
    line_offset:      int,
    filepath:         string,
    buffer:           string,
    offset:           int,
    max_offset:       int,
    whitespace_left:  bool,
    whitespace_right: bool,
}

start_tokenizer :: proc() -> (result: Tokenizer) {
    result.file_index = -1
    prepare_next_file(&result)
    return
}

prepare_next_file :: proc(t: ^Tokenizer, loc := #caller_location) {
    t.line_count = 1
    t.line_offset = 0
    t.offset = 0
    t.whitespace_left = false
    t.whitespace_right = false

    t.file_index += 1

    if t.file_index >= len(skc.input) {
        log.errorf(ERROR_COMPILER_BUG, loc)
        cleanup_exit(2)
    }

    t.filepath = skc.input[t.file_index]
    buf, _ := os.read_entire_file(t.filepath, context.temp_allocator)
    t.buffer = string(buf)
    t.max_offset = len(t.buffer)

    if t.file_index == len(skc.input) - 1 {
        t.is_last_file = true
    }
}

tokenize_files :: proc() {
    tokenizer := start_tokenizer()

    fmt.println(tokenizer.buffer)

    for {
        token := get_next_token(&tokenizer)

        fmt.println(token)

        if token.kind == .eof {
            if tokenizer.is_last_file { break }

            prepare_next_file(&tokenizer)
        }
    }
}

get_next_token :: proc(t: ^Tokenizer) -> (token: Token) {
    skip_whitespaces(t)

    token.offset = t.offset
    token.line   = t.line_count
    token.column = t.line_offset
    token.file   = t.filepath
    token.kind   = .eof

    if is_eof(t) { return }

    if is_alpha(t) || is_char(t, '_') {
        parse_identifier(t, &token)
    } else if is_number(t) {
        parse_number(t, &token)
    } else {
        switch get_char_at(t) {
        case '\'': fallthrough
        case '"':  parse_string_literal(t, &token)
        case '\n': parse_newline(t, &token)
        case :     token.kind = .invalid; t.offset += 1
        }
    }

    t.line_offset += t.offset - token.offset

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
    return c == ' ' || c == '\t' || c == '\r'
}

parse_identifier :: proc(t: ^Tokenizer, token: ^Token) {
    // TODO: Add language internal words
    token.kind  = .identifier
    token.value = get_word_at(t)
}

parse_newline :: proc(t: ^Tokenizer, token: ^Token) {
    token.kind = .newline
    t.offset += 1
    t.line_count += 1
    t.line_offset = 0
}

parse_number :: proc(t: ^Tokenizer, token: ^Token) {
    token.kind  = .integer
    token.value = get_word_at(t)
}

parse_string_literal :: proc(t: ^Tokenizer, token: ^Token) {
    delimiter := get_char_at(t)

    if is_eof(t) { return }
    t.offset += 1

    token.kind = delimiter == '\'' ? .character : .string
    is_escaped := false

    for !is_eof(t) {
        if is_char(t, delimiter) && !is_escaped { break }
        is_escaped = !is_escaped && is_char(t, '\\')
        t.offset += 1
    }

    if is_eof(t) { return }
    t.offset += 1

    // Store the string or the character, without the quotes
    token.value = t.buffer[token.offset + 1:t.offset - 1]
}
