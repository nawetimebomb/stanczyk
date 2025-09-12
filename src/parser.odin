package main

import "core:fmt"
import "core:strconv"
import "core:strings"

PARSER_IDENTIFIER_IN_FILE_SCOPE :: "We found an attempt to use an identifier statement at file scope, this is not allowed."
PARSER_OPERATOR_IN_FILE_SCOPE   :: "We found an operator in file scope."
PARSER_VALUE_IN_FILE_SCOPE      :: "We found an attempt to stack a value from file scope, this is not allowed."
PARSER_FOREIGN_MISPLACED        :: "#foreign can only be used in procedures with no bodies."
PARSER_UNEXPECTED_TOKEN         :: "Unexpected token {} while in {} scope."

Parsing_Scope_Kind :: enum u8 {
    File = 0,

    Procedure_Arguments = 1,
    Procedure_Results   = 2,
    Procedure_Body      = 3,
}

Parser :: struct {
    file_info:         ^File_Info,
    errors:            [dynamic]Compiler_Error,
    error_in_context:  bool,

    prev_token:        Token,
    curr_token:        Token,
    lexer:             Lexer,
    scope:             ^Parsing_Scope,
    file_scope:        ^Parsing_Scope,
}

Parsing_Scope :: struct {
    proc_decl:  ^Op_Proc_Decl,
    body:       ^[dynamic]^Op_Code,
    kind:       Parsing_Scope_Kind,
    previous:   ^Parsing_Scope,
    ip_counter: int,
}

parser_error :: proc(parser: ^Parser, format: string, args: ..any) {
    parser.error_in_context = true
    message := fmt.aprintf(format, ..args)
    append(&parser.errors, Compiler_Error{
        message = message,
        token   = parser.prev_token,
    })
}

parser_fatal_error :: proc(parser: ^Parser) {
    report_all_errors(parser.errors[:])
    errors_count := len(parser.errors)
    fatalf(
        .Parser,
        "found {} {} while parsing {}",
        errors_count,
        errors_count > 1 ? "errors" : "error",
        parser.file_info.fullpath,
    )
}

write_op_code :: proc(parser: ^Parser, token: Token, variant: Op_Variant) {
    op := new(Op_Code)
    op.local_ip = parser.scope.ip_counter
    op.token    = token
    op.variant  = variant
    append(parser.scope.body, op)
    parser.scope.ip_counter += 1
}

push_parser_scope :: proc(parser: ^Parser, kind: Parsing_Scope_Kind, body: ^[dynamic]^Op_Code) -> ^Parsing_Scope {
    new_scope := new(Parsing_Scope)
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
        parser_error(parser, "Expected {}, got {}", kind, token.kind)
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

    parser.file_scope = push_parser_scope(parser, .File, &program_bytecode)
    parser.scope = parser.file_scope

    init_lexer(parser)
    next(parser)

    for {
        parser.error_in_context = false
        should_leave := parse_expression(parser)
        if should_leave do break
    }

    if len(parser.errors) > 0 {
        parser_fatal_error(parser)
    }

    total_lines_count += parser.lexer.line

    //fmt.printfln("\n======== {}\n", parser.file_info.filename)
    //for op, index in program_bytecode do print_op_debug(op)
    //fmt.printfln("======== {}\n", parser.file_info.filename)

    pop_scope(parser)

    assert(parser.scope == nil)
    free(parser)
}

parse_expression :: proc(parser: ^Parser) -> (should_leave: bool) {
    token := next(parser)

    switch token.kind {
    case .Invalid:
        parser_error(parser, "Invalid token found {}", token.text)

    case .Dash_Dash_Dash:
        // special case because this is only
        // allowed when parsing arguments
        if parser.scope.body != &parser.scope.proc_decl.arguments {
            parser_error(
                parser, PARSER_UNEXPECTED_TOKEN, token.text, parser.scope.kind,
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

    case .Print:
        write_op_code(parser, token, Op_Print{})
    }

    return false
}

parse_binary :: proc(parser: ^Parser, token: Token) {
    // not allowed in global scope
    if parser.scope.kind == .File {
        parser_error(parser, PARSER_OPERATOR_IN_FILE_SCOPE)
    }

    write_op_code(parser, token, Op_Binary{token})
}

parse_foreign :: proc(parser: ^Parser, token: Token) {
    if parser.scope.proc_decl == nil {
        parser_error(parser, PARSER_FOREIGN_MISPLACED)
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

    push_parser_scope(parser, .Procedure_Body, &proc_decl.body)
    parser.scope.proc_decl = &proc_decl

    if allow(parser, .Paren_Left) {
        parser.scope.kind = .Procedure_Arguments
        parser.scope.body = &proc_decl.arguments

        for !parser.error_in_context {
            should_leave := parse_expression(parser)
            if should_leave do break
        }

        if was(parser, .Dash_Dash_Dash) {
            parser.scope.kind = .Procedure_Results
            parser.scope.body = &proc_decl.results

            for !parser.error_in_context {
                should_leave := parse_expression(parser)
                if should_leave do break
            }
        }

        parser.scope.kind = .Procedure_Body
        parser.scope.body = &proc_decl.body
    }

    for !parser.error_in_context {
        should_leave := parse_expression(parser)
        if should_leave do break
    }

    if parser.error_in_context {
        for !allow(parser, .Semicolon) && !allow(parser, .EOF) do next(parser)
        pop_scope(parser)
        return
    }

    write_op_code(parser, token, Op_Return{})

    pop_scope(parser)
    write_op_code(parser, token, proc_decl)
}

parse_identifier :: proc(parser: ^Parser, token: Token) {
    // not allowed in global scope
    if parser.scope.kind == .File {
        parser_error(parser, PARSER_IDENTIFIER_IN_FILE_SCOPE)
    }

    write_op_code(parser, token, Op_Identifier{token})
}

parse_type :: proc(parser: ^Parser, token: Token) {
    // not allowed in global scope
    if parser.scope.kind == .File {
        parser_error(parser, PARSER_IDENTIFIER_IN_FILE_SCOPE)
    }

    write_op_code(parser, token, Op_Type{token})
}

parse_value :: proc(parser: ^Parser, token: Token) {
    // not allowed in global scope
    if parser.scope.kind == .File {
        parser_error(parser, PARSER_VALUE_IN_FILE_SCOPE)
        return
    }

    write_op_code(parser, token, Op_Basic_Literal{token})
}
