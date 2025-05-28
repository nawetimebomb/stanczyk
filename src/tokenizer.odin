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

    Colon_Colon,
    Colon_Equal,
    Dash_Dash_Dash,
    Semicolon,
    Let,

    Binary_Literal,
    Character_Literal,
    False_Literal,
    Float_Literal,
    Hex_Literal,
    Integer_Literal,
    Octal_Literal,
    String_Literal,
    True_Literal,

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

    Any,
    Bool,
    Float,
    Int,
    Quote,
    String,
    Uint,
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
        .Colon_Colon = "::",
        .Colon_Equal = ":=",
        .Dash_Dash_Dash = "---",
        .Semicolon = ";",
        .Let = "let",

        .Binary_Literal = "literal binary. Example 0b10",
        .Character_Literal = "literal character. Example: 'a'",
        .False_Literal = "literal boolean false",
        .Float_Literal = "literal float. Example: 3.14",
        .Hex_Literal = "literal hex. Example: 0xff",
        .Integer_Literal = "literal integer. Example: 1337",
        .Octal_Literal = "literal octal. Example 0o07",
        .String_Literal = "literal string. Example: \"Hello\"",
        .True_Literal = "literal boolean true",

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

        .Any = "any",
        .Bool = "bool",
        .Float = "float",
        .Int = "int",
        .Quote = "quote",
        .String = "string",
        .Uint = "uint",
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

        if _, maybe_int := strconv.parse_int(token.text); maybe_int {
            // TODO: This can be hex, octal or binary. Check for these.
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

        if _, maybe_float := strconv.parse_f64(token.text); maybe_float {
            token.kind = .Float_Literal
            return
        }

        if token.text == "//" {
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
    case "::": kind = .Colon_Colon
    case ":=": kind = .Colon_Equal
    case "---": kind = .Dash_Dash_Dash
    case ";": kind = .Semicolon
    case "let": kind = .Let

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
    case "any": kind = .Any
    case "bool": kind = .Bool
    case "float": kind = .Float
    case "int": kind = .Int
    case "quote": kind = .Quote
    case "string": kind = .String
    case "uint": kind = .Uint
    }

    return kind
}

token_to_string :: proc(token: Token) -> string {
    if token.kind == .Word {
        return fmt.tprintf("Word with content: %s", token.text)
    }
    return token_string_table[token.kind]
}
