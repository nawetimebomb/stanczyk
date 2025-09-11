package main

import "core:fmt"
import "core:strconv"
import "core:strings"

ERROR_IDENTIFIER_IN_FILE_SCOPE :: "We found an attempt to use an identifier statement at file scope, this is not allowed."
ERROR_OPERATOR_IN_FILE_SCOPE   :: "We found an operator in file scope."
ERROR_VALUE_IN_FILE_SCOPE      :: "We found an attempt to stack a value from file scope, this is not allowed."
ERROR_FOREIGN_MISPLACED        :: "#foreign can only be used in procedures with no bodies."
ERROR_UNEXPECTED_TOKEN         :: "Unexpected token {} while in {} scope."

Parser_Error_Kind :: enum {
    Syntax,
}

Scope_Kind :: enum {
    File,
    Procedure,
}

Parser :: struct {
    file_info:         ^File_Info,
    errors:            [dynamic]Parser_Error,
    error_in_context:  bool,

    prev_token:        Token,
    curr_token:        Token,
    lexer:             Lexer,
    scope:             ^Scope,
    file_scope:        ^Scope,
}

Parser_Error :: struct {
    message: string,
    kind:    Parser_Error_Kind,
    token:   Token,
}

Scope :: struct {
    proc_decl:  ^Op_Proc_Decl,
    body:       ^[dynamic]Op_Code,
    kind:       Scope_Kind,
    previous:   ^Scope,
    ip_counter: int,
}

parsing_error :: proc(parser: ^Parser, kind: Parser_Error_Kind, format: string, args: ..any) {
    message := fmt.aprintf(format, ..args)
    append(&parser.errors, Parser_Error{
        kind    = kind,
        message = message,
        token   = parser.prev_token,
    })
}

print_all_errors :: proc(parser: ^Parser) {
    line_number_to_string :: proc(number: int) -> string {
        number_str := fmt.tprintf("{}", number)
        return strings.right_justify(number_str, 4, " ")
    }

    for error in parser.errors {
        token := error.token
        fmt.eprintfln(
            "\e[1m{}({}:{})\e[0;91m {} Error:\e[0m {}",
            token.fullpath, token.l0, token.c0, error.kind, error.message,
        )
        fmt.eprint("\e[0;36m")
        if token.l0 > 1 {
            line_index := max(token.l0-2, 0)
            count_of_chars := 0
            for line_index > 0 && count_of_chars == 0 {
                start := parser.lexer.line_starts[line_index]
                end := parser.lexer.line_starts[line_index+1] - 1
                count_of_chars = end - start
                if count_of_chars == 0 do line_index -= 1
            }
            line_index = max(line_index, 0)
            start := parser.lexer.line_starts[line_index]
            text := parser.lexer.data[start:token.start]
            token_start_index := token.start - start

            fmt.eprintf("\t{} | \t", line_number_to_string(line_index + 1))
            for r, index in text {
                fmt.eprint(r)

                if r == '\n' {
                    line_index += 1
                    fmt.eprintf("\t{} | \t", line_number_to_string(line_index + 1))
                }
            }

            error_red(parser.lexer.data[token.start:token.end])
        } else {
            curr_line := parser.lexer.data[:token.end]
            fmt.eprintfln("\t{} | \t{}", token.l0, curr_line)
        }

        fmt.eprint("\e[0m\n")
    }
}

write_op_code :: proc(parser: ^Parser, token: Token, variant: Op_Variant) {
    append(parser.scope.body, Op_Code{
        local_ip  = parser.scope.ip_counter,
        token     = token,
        variant   = variant,
    })
    parser.scope.ip_counter += 1
}

push_scope :: proc(parser: ^Parser, kind: Scope_Kind, body: ^[dynamic]Op_Code) -> ^Scope {
    new_scope := new(Scope)
    new_scope.body     = body
    new_scope.kind     = kind
    new_scope.previous = parser.scope
    parser.scope = new_scope
    return new_scope
}

pop_scope :: proc(parser: ^Parser) {
    old_scope := parser.scope
    parser.scope = old_scope.previous
}

allow :: proc(parser: ^Parser, kind: Token_Kind) -> bool {
    if parser.curr_token.kind == kind {
        next(parser)
        return true
    }
    return false
}

was :: proc(parser: ^Parser, kind: Token_Kind) -> bool {
    return parser.prev_token.kind == kind
}

expect :: proc(parser: ^Parser, kind: Token_Kind) -> (token: Token) {
    token = next(parser)

    if token.kind != kind {
        parsing_error(parser, .Syntax, "Expected {}, got {}", kind, token.kind)
        for {
            token := next(parser)
            if token.kind == .EOF || token.kind == .Semicolon do break
        }
    }

    return
}

next :: proc(parser: ^Parser) -> Token {
    token := get_next_token(&parser.lexer)
    parser.prev_token = parser.curr_token
    parser.curr_token = token
    return parser.prev_token
}

parse_file :: proc(file_info: ^File_Info) {
    parser := new(Parser)
    parser.file_info = file_info

    parser.file_scope = push_scope(parser, .File, &program_bytecode)
    parser.scope = parser.file_scope

    init_lexer(parser)
    next(parser)

    for {
        parser.error_in_context = false
        should_leave := parse_expression(parser)
        if should_leave do break
    }

    if len(parser.errors) > 0 {
        print_all_errors(parser)
        errors_count := len(parser.errors)
        fatalf(
            .Parsing_Errors,
            "found {} {} while parsing {}",
            errors_count,
            errors_count > 1 ? "errors" : "error",
            parser.file_info.fullpath,
        )
    }

    fmt.println("\n========")
    for op, index in program_bytecode {
        print_op_debug(op)
    }
    fmt.println("========\n")

    pop_scope(parser)

    assert(parser.scope == nil)
    free(parser)
}

parse_expression :: proc(parser: ^Parser) -> (should_leave: bool) {
    token := next(parser)

    switch token.kind {
    case .Dash_Dash_Dash:
        // special case because this is only
        // allowed when parsing arguments
        if parser.scope.body != &parser.scope.proc_decl.arguments {
            parsing_error(
                parser, .Syntax,
                ERROR_UNEXPECTED_TOKEN,
                token.text, parser.scope.kind,
            )
        }
        return true

    case .EOF:                 return true
    case .Semicolon:           return true
    case .Paren_Left:          return true
    case .Paren_Right:         return true
    case .Comment:             return false


    case .Identifier:          parse_identifier(parser, token)
    case .Integer:             parse_value     (parser, token)
    case .Unsigned_Integer:    parse_value     (parser, token)
    case .Float:               parse_value     (parser, token)
    case .Hex:                 parse_value     (parser, token)
    case .Binary:              parse_value     (parser, token)
    case .Octal:               parse_value     (parser, token)
    case .String:              parse_value     (parser, token)
    case .Char:                parse_value     (parser, token)
    case .True:                parse_value     (parser, token)
    case .False:               parse_value     (parser, token)
    case .Type_Int:            parse_type      (parser, token)
    case .Type_Uint:           parse_type      (parser, token)
    case .Type_Float:          parse_type      (parser, token)
    case .Type_Bool:           parse_type      (parser, token)
    case .Type_String:         parse_type      (parser, token)
    case .Brace_Left:          unimplemented()
    case .Brace_Right:         unimplemented()
    case .Bracket_Left:        unimplemented()
    case .Bracket_Right:       unimplemented()
    case .Minus:               parse_binary    (parser, token)
    case .Plus:                parse_binary    (parser, token)
    case .Star:                parse_binary    (parser, token)
    case .Slash:               parse_binary    (parser, token)
    case .Percent:             parse_binary    (parser, token)
    case .Using:               unimplemented()
    case .Proc:                parse_proc_decl (parser, token)
    case .Foreign:             parse_foreign   (parser, token); return true
    }

    return false
}

parse_binary :: proc(parser: ^Parser, token: Token) {
    // not allowed in global scope
    if parser.scope.kind == .File {
        parsing_error(
            parser,
            .Syntax,
            ERROR_OPERATOR_IN_FILE_SCOPE,
        )
    }

    write_op_code(parser, token, Op_Binary{token})
}

parse_foreign :: proc(parser: ^Parser, token: Token) {
    if parser.scope.proc_decl == nil {
        parsing_error(
            parser,
            .Syntax,
            ERROR_FOREIGN_MISPLACED,
        )
    }

    parser.scope.proc_decl.is_foreign = true

    if allow(parser, .Identifier) {
        parser.scope.proc_decl.foreign_lib = parser.prev_token
    }

    expect(parser, .Semicolon)
}

parse_proc_decl :: proc(parser: ^Parser, token: Token) {
    proc_decl := Op_Proc_Decl{}
    proc_decl.name = expect(parser, .Identifier)
    if parser.error_in_context do return

    proc_decl.scope = push_scope(parser, .Procedure, &proc_decl.body)
    parser.scope.proc_decl = &proc_decl

    if allow(parser, .Paren_Left) {
        parser.scope.body = &proc_decl.arguments

        for {
            should_leave := parse_expression(parser)
            if should_leave do break
        }

        if was(parser, .Dash_Dash_Dash) {
            parser.scope.body = &proc_decl.results
            for {
                should_leave := parse_expression(parser)
                if should_leave do break
            }
        }

        parser.scope.body = &proc_decl.body
    }

    for {
        should_leave := parse_expression(parser)
        if should_leave do break
    }

    pop_scope(parser)
    write_op_code(parser, token, proc_decl)
}

parse_identifier :: proc(parser: ^Parser, token: Token) {
    // not allowed in global scope
    if parser.scope.kind == .File {
        parsing_error(
            parser,
            .Syntax,
            ERROR_IDENTIFIER_IN_FILE_SCOPE,
        )
    }

    write_op_code(parser, token, Op_Identifier{token})
}

parse_type :: proc(parser: ^Parser, token: Token) {
    // not allowed in global scope
    if parser.scope.kind == .File {
        parsing_error(
            parser,
            .Syntax,
            ERROR_IDENTIFIER_IN_FILE_SCOPE,
        )
    }

    #partial switch token.kind {
    case .Type_Int:    write_op_code(parser, token, Op_Type{get_basic_type(.Int)})
    case .Type_Uint:   write_op_code(parser, token, Op_Type{get_basic_type(.Uint)})
    case .Type_Float:  write_op_code(parser, token, Op_Type{get_basic_type(.Float)})
    case .Type_Bool:   write_op_code(parser, token, Op_Type{get_basic_type(.Bool)})
    case .Type_String: write_op_code(parser, token, Op_Type{get_basic_type(.String)})
    }
}

parse_value :: proc(parser: ^Parser, token: Token) {
    // not allowed in global scope
    if parser.scope.kind == .File {
        parsing_error(
            parser,
            .Syntax,
            ERROR_VALUE_IN_FILE_SCOPE,
        )
        return
    }

    value := Op_Basic_Literal{value=token}

    #partial switch token.kind {
    case .Binary:           value.type = get_basic_type(.Int)
    case .Char:             value.type = get_basic_type(.Char)
    case .Float:            value.type = get_basic_type(.Float)
    case .Hex:              value.type = get_basic_type(.Int)
    case .Integer:          value.type = get_basic_type(.Int)
    case .Octal:            value.type = get_basic_type(.Int)
    case .String:           value.type = get_basic_type(.String)
    case .Unsigned_Integer: value.type = get_basic_type(.Uint)

    case .False:            fallthrough
    case .True:             value.type = get_basic_type(.Bool)
    case: unimplemented()
    }

    write_op_code(parser, token, value)
}
