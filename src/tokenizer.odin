package main

import "core:fmt"
import "core:strconv"
import "core:strings"

Position :: struct {
    filename: string,
    column:   int,
    line:     int,
    offset:    int,
    internal: bool,
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

    As, Const, Var, Type, Proc,
    Builtin, Foreign,
    Dash_Dash_Dash, Semicolon,
    Ampersand, Hat,

    Let, In, End,
    Case, Else, Fi, If,
    For, For_Star, Loop,
    Leave,

    Get_Byte,
    Set, Set_Star, Set_Byte,

    Binary_Literal, Character_Literal, Cstring_Literal,
    Bool_Literal, Float_Literal, Hex_Literal,
    Integer_Literal, Octal_Literal, String_Literal,
    Uint_Literal,

    Plus, Minus, Star, Slash, Percent,
    Equal, Greater_Equal, Greater_Than,
    Less_Equal, Less_Than, Not_Equal,
    Greater_Than_Auto, Greater_Equal_Auto,
    Less_Than_Auto, Less_Equal_Auto,

    Drop, Dup, Dup_Star, Nip, Over, Rot,
    Rot_Star, Swap, Take, Tuck,
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

        .As = "as", .Const = "const", .Var = "var", .Type = "type", .Proc = "proc",
        .Builtin = "builtin", .Foreign = "foreign",
        .Dash_Dash_Dash = "---", .Semicolon = ";",
        .Ampersand = "&", .Hat = "^",

        .Let = "let",
        .In = "in",
        .End = "end",

        .Case = "case", .Else = "else",
        .Fi = "fi", .If = "if",
        .For = "for", .For_Star = "for*",
        .Loop = "loop",
        .Leave = "leave",

        .Get_Byte = "get-byte",
        .Set = "set", .Set_Star = "set*", .Set_Byte = "set-byte",

        .Binary_Literal = "literal binary. Example 0b10 or 2b",
        .Bool_Literal = "literal boolean. Example: false or true",
        .Character_Literal = "literal character. Example: 'a'",
        .Cstring_Literal = "literal C string. Example: \"Hello\"c",
        .Float_Literal = "literal float. Example: 3.14",
        .Hex_Literal = "literal hex. Example: 0xff or 16x",
        .Integer_Literal = "literal integer. Example: 1337",
        .Octal_Literal = "literal octal. Example 0o07 or 8o",
        .String_Literal = "literal string. Example: \"Hello\"",
        .Uint_Literal = "literal unsigned integer. Example: 1337u",

        .Plus = "+", .Minus = "-", .Star = "*", .Slash = "/", .Percent = "%",
        .Equal = "=", .Greater_Equal = ">=", .Greater_Than = ">",
        .Less_Equal = "<=", .Less_Than = "<", .Not_Equal = "!=",
        .Greater_Than_Auto = "..>", .Greater_Equal_Auto = "..>=",
        .Less_Than_Auto = "..<", .Less_Equal_Auto = "..<=",

        .Drop = "drop", .Dup = "dup", .Dup_Star = "dup*", .Nip = "nip",
        .Over = "over", .Rot = "rot", .Rot_Star = "rot*", .Swap = "swap",
        .Take = "take", .Tuck = "tuck",
}

tokenizer_init :: proc(t: ^Tokenizer, source: Source_File) {
    t.data = source.data
    t.filename = source.filename
    t.internal = source.internal
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

    is_special_char :: proc(t: ^Tokenizer) -> bool {
        c := t.data[t.offset]
        return c == '(' || c == ')' || c == ';'
    }

    skip_whitespace :: proc(t: ^Tokenizer) {
        old_offset := t.offset
        loop: for t.offset < len(t.data) {
            if is_special_char(t) || !is_whitespace(t) { break loop }
            advance(t)
        }
    }

    forward_word :: proc(t: ^Tokenizer) {
        loop: for t.offset < len(t.data) {
            if is_special_char(t) || is_whitespace(t) { break loop }
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
                    parsing_error(
                        token.pos,
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
    token.internal = t.internal
    token.kind = .Word

    if t.offset >= len(t.data) {
        token.kind = .EOF
        return
    }

    switch t.data[t.offset] {
    case '(':
        token.kind = .Paren_Left
        advance(t)
        return
    case ')':
        token.kind = .Paren_Right
        advance(t)
        return
    case ';':
        token.kind = .Semicolon
        advance(t)
        return
    case '&':
        token.kind = .Ampersand
        advance(t)
        return
    case '^':
        token.kind = .Hat
        advance(t)
        return
    case '\'', '"':
        delimiter := t.data[t.offset]
        result := strings.builder_make(context.temp_allocator)
        token.kind = delimiter == '\'' ? .Character_Literal : .String_Literal
        is_escaped := false
        advance(t)

        for t.offset < len(t.data) {
            if t.data[t.offset] == delimiter && !is_escaped { break }
            c := t.data[t.offset]
            is_escaped = !is_escaped && c == '\\'
            if is_escaped {
                advance(t)
                c = t.data[t.offset]
                r: byte
                switch c {
                case '\\': r = '\\'
                case 'e':  r = '\e'
                case 'n':  r = '\n'
                case 't':  r = '\t'
                case : r = c
                }
                strings.write_byte(&result, r)
                is_escaped = false
            } else {
                strings.write_byte(&result, c)
            }
            advance(t)
        }

        advance(t)
        token.text = strings.to_string(result)

        if token.kind == .String_Literal && t.data[t.offset] == 'c' {
            token.kind = .Cstring_Literal
            advance(t)
        }

        if token.kind == .Character_Literal && len(token.text) > 1 {
            parsing_error(
                token.pos,
                "character literal cannot have length {} found at {}:{}:{}",
                len(token.text), token.filename, token.line, token.column,
            )
        }
    case :
        forward_word(t)
        token.text = string(t.data[token.offset:t.offset])

        if ok := try_evaluate_as_number(&token); ok {
            return
        }

        comment_scope_count := 0

        if strings.starts_with(token.text, "/*") {
            comment_scope_count += 1

            // skips until the end of this comment block
            comment_block_loop: for {
                token, _ := get_next_token(t)
                switch {
                case strings.starts_with(token.text, "/*"): comment_scope_count += 1
                case strings.ends_with(token.text, "*/"): comment_scope_count -= 1
                }

                if token.kind == .EOF {
                    unexpected_end_of_file()
                }

                if comment_scope_count == 0 {
                    break comment_block_loop
                }
            }

            return get_next_token(t)
        }

        if strings.starts_with(token.text, "//") {
            // skips this token because it's a comment, loop through the line,
            // then return the next immediate token
            comment_line_loop: for t.offset < len(t.data) {
                if t.data[t.offset] == '\n' { break comment_line_loop }
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

    case "as": kind = .As
    case "const": kind = .Const
    case "var": kind = .Var
    case "type": kind = .Type
    case "proc": kind = .Proc
    case "builtin": kind = .Builtin
    case "foreign": kind = .Foreign
    case "---": kind = .Dash_Dash_Dash

    case "let": kind = .Let
    case "in": kind = .In
    case "end": kind = .End
    case "case": kind = .Case
    case "else": kind = .Else
    case "if": kind = .If
    case "fi": kind = .Fi

    case "for": kind = .For
    case "for*": kind = .For_Star
    case "loop": kind = .Loop
    case "leave": kind = .Leave

    case "get-byte": kind = .Get_Byte
    case "set": kind = .Set
    case "set*": kind = .Set_Star
    case "set-byte": kind = .Set_Byte

    case "false": kind = .Bool_Literal
    case "true": kind = .Bool_Literal

    case "+": kind = .Plus
    case "-": kind = .Minus
    case "*": kind = .Star
    case "/": kind = .Slash
    case "%": kind = .Percent
    case "=": kind = .Equal
    case ">=": kind = .Greater_Equal
    case "..>=": kind = .Greater_Equal_Auto
    case ">": kind = .Greater_Than
    case "..>": kind = .Greater_Than_Auto
    case "<=": kind = .Less_Equal
    case "..<=": kind = .Less_Equal_Auto
    case "<": kind = .Less_Than
    case "..<": kind = .Less_Than_Auto
    case "!=": kind = .Not_Equal

    case "drop": kind = .Drop
    case "dup": kind = .Dup
    case "dup*": kind = .Dup_Star
    case "nip": kind = .Nip
    case "over": kind = .Over
    case "rot": kind = .Rot
    case "rot*": kind = .Rot_Star
    case "swap": kind = .Swap
    case "take": kind = .Take
    case "tuck": kind = .Tuck
    }

    return kind
}

token_to_string :: proc(token: Token) -> string {
    if token.kind == .Word {
        return fmt.tprintf("Word with content: %s", token.text)
    }
    return token_string_table[token.kind]
}

token_pos :: proc(token: Token) -> (string, int, int) {
    return token.pos.filename, token.pos.line, token.pos.column
}
