package main

import "core:fmt"
import "core:strconv"
import "core:strings"

Position :: struct {
    filename: string,
    column:   int,
    line:     int,
    offset:   int,
}

Error :: enum {
    None,
    Illegal_Word,
}

Token_Kind :: enum u8 {
    Invalid = 0,
    EOF,

    Using,
    Word,

    Brace_Left,
    Brace_Right,
    Bracket_Left,
    Bracket_Right,
    Paren_Left,
    Paren_Right,

    Const, Fn,
    Dash_Dash_Dash,
    Semicolon,

    Let, In, End,
    Case, Elif, Else, Fi, If, Then,

    Binary_Literal,
    Character_Literal,
    False_Literal,
    Float_Literal,
    Hex_Literal,
    Integer_Literal,
    Octal_Literal,
    String_Literal,
    True_Literal,
    Type_Literal,
    Uint_Literal,

    Add,
    Divide,
    Multiply,
    Modulo,
    Substract,

    Equal,
    Greater_Equal,
    Greater_Than,
    Less_Equal,
    Less_Than,
    Not_Equal,
}

Token :: struct {
    using pos: Position,
    kind: Token_Kind,
    text: string,
}

Tokenizer :: struct {
    using pos: Position,
    data:      string,
}

token_string_table := [Token_Kind]string{
        .Invalid = "invalid",
        .EOF = "EOF",
        .Using = "using",
        .Word = "user-specified word",
        .Brace_Left = "{",
        .Brace_Right = "}",
        .Bracket_Left = "[",
        .Bracket_Right = "]",
        .Paren_Left = "(",
        .Paren_Right = ")",

        .Const = "const",
        .Fn = "fn",
        .Dash_Dash_Dash = "---",
        .Semicolon = ";",

        .Let = "let",
        .In = "in",
        .End = "end",

        .Case = "case", .Elif = "elif", .Else = "else",
        .Fi = "fi", .If = "if", .Then = "then",

        .Binary_Literal = "literal binary. Example 0b10 or 2b",
        .Character_Literal = "literal character. Example: 'a'",
        .False_Literal = "literal boolean false",
        .Float_Literal = "literal float. Example: 3.14",
        .Hex_Literal = "literal hex. Example: 0xff or 16x",
        .Integer_Literal = "literal integer. Example: 1337",
        .Octal_Literal = "literal octal. Example 0o07 or 8o",
        .String_Literal = "literal string. Example: \"Hello\"",
        .True_Literal = "literal boolean true",
        .Type_Literal = "literal type name. Example: int",
        .Uint_Literal = "literal unsigned integer. Example: 1337u",

        .Add = "+",
        .Divide = "/",
        .Modulo = "%",
        .Multiply = "*",
        .Substract = "-",

        .Equal = "=",
        .Greater_Equal = ">=",
        .Greater_Than = ">",
        .Less_Equal = "<=",
        .Less_Than = "<",
        .Not_Equal = "!=",
}

tokenizer_init :: proc(t: ^Tokenizer, filename, data: string) {
    t.data = data
    t.filename = filename
    t.line = 1
    t.column = 0
    t.offset = 0
}

get_next_token :: proc(t: ^Tokenizer) -> (token: Token, err: Error) {
    advance :: proc(t: ^Tokenizer, loc := #caller_location) {
        t.offset += 1
        t.column += 1
        if t.offset >= len(t.data) { return }
        if t.data[t.offset] == '\n' {
            t.column = -1
            t.line += 1
        }
    }

    is_whitespace :: proc(t: ^Tokenizer) -> bool {
        c := t.data[t.offset]
        return c == ' ' || c == '\t' || c == '\r' || c == '\n'
    }

    skip_whitespace :: proc(t: ^Tokenizer) {
        old_offset := t.offset
        loop: for t.offset < len(t.data) {
            if !is_whitespace(t) { break loop }
            advance(t)
        }
    }

    forward_word :: proc(t: ^Tokenizer) {
        loop: for t.offset < len(t.data) {
            if is_whitespace(t) { break loop }
            advance(t)
        }
    }

    try_evaluate_as_number :: proc(token: ^Token) -> (ok: bool) {
        if len(token.text) > 1 {
            first_part := token.text[:len(token.text) - 1]
            last_part := token.text[len(token.text) - 1]
            _, maybe_int := strconv.parse_int(first_part)

            switch {
            case last_part == 'b' && maybe_int:
                token.text = first_part
                token.kind = .Binary_Literal
                return true
            case last_part == 'f' && maybe_int:
                token.text = first_part
                token.kind = .Float_Literal
                return true
            case last_part == 'i' && maybe_int:
                token.text = first_part
                token.kind = .Integer_Literal
                return true
            case last_part == 'o' && maybe_int:
                token.text = first_part
                token.kind = .Octal_Literal
                return true
            case last_part == 'u' && maybe_int:
                if strings.starts_with(first_part, "-") {
                    global_errorf(
                        "unsigned integer with a sign ({}) found at {}:{}:{}",
                        token.text, token.filename, token.line, token.column,
                    )
                }
                token.text = first_part
                token.kind = .Uint_Literal
                return true
            case last_part == 'x' && maybe_int:
                token.text = first_part
                token.kind = .Hex_Literal
                return true
            }
        }

        if _, ok = strconv.parse_int(token.text); ok {
            token.kind = .Integer_Literal

            if len(token.text) > 1 {
                switch token.text[1] {
                case 'b': token.kind = .Binary_Literal
                case 'o': token.kind = .Octal_Literal
                case 'x': token.kind = .Hex_Literal
                }
            }

            return
        }

        if _, ok = strconv.parse_f64(token.text); ok {
            token.kind = .Float_Literal
            return
        }

        return false
    }

    skip_whitespace(t)

    token.filename = t.filename
    token.column = t.column
    token.line = t.line
    token.offset = t.offset
    token.kind = .Word

    if t.offset >= len(t.data) {
        token.kind = .EOF
        return
    }

    if t.data[t.offset] == '\'' || t.data[t.offset] == '"' {
        delimiter := t.data[t.offset]
        result := strings.builder_make(context.temp_allocator)
        token.kind = delimiter == '\'' ? .Character_Literal : .String_Literal
        is_escaped := false
        advance(t)

        for t.offset < len(t.data) {
            if t.data[t.offset] == delimiter && !is_escaped { break }
            c := t.data[t.offset]
            switch c {
            case '\t', '\v', '\f', '\r', '\n':
                strings.write_byte(&result, '\\')
                strings.write_byte(&result, c)
            case :
                strings.write_byte(&result, c)
            }
            is_escaped = !is_escaped && c == '\\'
            advance(t)
        }

        advance(t)
        token.text = strings.to_string(result)
    } else {
        forward_word(t)
        token.text = string(t.data[token.offset:t.offset])

        if ok := try_evaluate_as_number(&token); ok {
            return
        }

        if strings.starts_with(token.text, "//") {
            // skips this token because it's a comment, loop through the line,
            // then return the next immediate token
            loop: for t.offset < len(t.data) {
                if t.data[t.offset] == '\n' { break loop }
                advance(t)
            }
            return get_next_token(t)
        }

        token.kind = string_to_token_kind(token.text)
    }

    return
}

string_to_token_kind :: proc(str: string) -> (kind: Token_Kind) {
    kind = .Word

    switch str {
    case "using": kind = .Using
    case "{": kind = .Brace_Left
    case "}": kind = .Brace_Right
    case "[": kind = .Bracket_Left
    case "]": kind = .Bracket_Right
    case "(": kind = .Paren_Left
    case ")": kind = .Paren_Right

    case "const": kind = .Const
    case "fn": kind = .Fn
    case "---": kind = .Dash_Dash_Dash
    case ";": kind = .Semicolon

    case "let": kind = .Let
    case "in": kind = .In
    case "end": kind = .End
    case "case": kind = .Case
    case "elif": kind = .Elif
    case "else": kind = .Else
    case "if": kind = .If
    case "fi": kind = .Fi
    case "then": kind = .Then

    case "false": kind = .False_Literal
    case "true": kind = .True_Literal

    case "+": kind = .Add
    case "/": kind = .Divide
    case "%": kind = .Modulo
    case "*": kind = .Multiply
    case "-": kind = .Substract

    case "=": kind = .Equal
    case ">=": kind = .Greater_Equal
    case ">": kind = .Greater_Than
    case "<=": kind = .Less_Equal
    case "<": kind = .Less_Than
    case "!=": kind = .Not_Equal

    case "any": kind = .Type_Literal
    case "bool": kind = .Type_Literal
    case "float": kind = .Type_Literal
    case "int": kind = .Type_Literal
    case "quote": kind = .Type_Literal
    case "string": kind = .Type_Literal
    case "uint": kind = .Type_Literal
    }

    return kind
}

token_to_string :: proc(token: Token) -> string {
    if token.kind == .Word {
        return fmt.tprintf("Word with content: %s", token.text)
    }
    return token_string_table[token.kind]
}
