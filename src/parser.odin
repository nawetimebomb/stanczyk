package main

import "core:fmt"
import "core:strconv"
import "core:strings"

PARSER_IDENTIFIER_IN_FILE_SCOPE :: "We found an attempt to use an identifier statement at file scope, this is not allowed."
PARSER_OPERATOR_IN_FILE_SCOPE   :: "We found an operator in file scope."
PARSER_VALUE_IN_FILE_SCOPE      :: "We found an attempt to stack a value from file scope, this is not allowed."
PARSER_FOREIGN_MISPLACED        :: "#foreign can only be used in procedures with no bodies."
PARSER_UNEXPECTED_TOKEN :: "Unexpected token {}."
PARSER_UNEXPECTED_EOF   :: "Unexpected end of file found."
PARSER_UNEXPECTED_TOKEN_IN_PROC_SIGNATURE :: "Unexpected token {} while parsing procedure signature."
PARSER_INVALID_NUMBER   :: "Found an invalid number."
PARSER_COMPILER_ERROR   :: "Compiler error"

Parsing_Context_Kind :: enum u8 {
    File      = 0,
    Procedure = 1,
}

Parser :: struct {
    file_info:         ^File_Info,
    errors:            [dynamic]Compiler_Error,
    error_in_context:  bool,

    prev_token:        Token,
    curr_token:        Token,
    lexer:             Lexer,
    current_context:     ^Parsing_Context,
    file_context:      ^Parsing_Context,
}

Parsing_Context :: struct {
    proc_decl:  ^Op_Proc_Decl,
    kind:       Parsing_Context_Kind,
    previous:   ^Parsing_Context,
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

is_eof :: proc(parser: ^Parser) -> bool {
    return parser.prev_token.kind == .EOF
}

create_op_code :: proc(parser: ^Parser, token: Token) -> ^Op_Code {
    op := new(Op_Code)
    op.token = token
    op.local_ip = parser.current_context.ip_counter
    parser.current_context.ip_counter += 1
    return op
}

write_op_code :: proc(chunk: ^[dynamic]^Op_Code, op: ^Op_Code) {
    append(chunk, op)
}

push_parsing_context :: proc(parser: ^Parser, kind: Parsing_Context_Kind) -> ^Parsing_Context {
    new_scope := new(Parsing_Context)
    new_scope.kind     = kind
    new_scope.previous = parser.current_context
    parser.current_context = new_scope
    return new_scope
}

pop_parsing_context :: proc(parser: ^Parser) {
    old_scope := parser.current_context
    parser.current_context = old_scope.previous
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

    parser.file_context = push_parsing_context(parser, .File)
    parser.current_context = parser.file_context

    init_lexer(parser)
    next(parser)

    main_loop: for !is_eof(parser) {
        if allow(parser, .EOF) {
            break main_loop
        }

        parser.error_in_context = false
        op := parse_expression(parser)
        if op == nil do break
        write_op_code(&program_bytecode, op)
    }

    if len(parser.errors) > 0 {
        parser_fatal_error(parser)
    }

    total_lines_count += parser.lexer.line

    pop_parsing_context(parser)

    assert(parser.current_context == nil)
    free(parser)
}

parse_expression :: proc(parser: ^Parser) -> ^Op_Code {
    token := next(parser)

    switch token.kind {
    case .Invalid:
        parser_error(parser, PARSER_UNEXPECTED_TOKEN, token.text)
        return nil

    case .Dash_Dash_Dash:
        parser_error(parser, PARSER_UNEXPECTED_TOKEN, token.text)
        return nil

    case .EOF:
        parser_error(parser, PARSER_UNEXPECTED_EOF)
        return nil

    case .Semicolon:
        parser_error(parser, PARSER_COMPILER_ERROR)
        return nil

    case .Paren_Left:
        parser_error(parser, PARSER_COMPILER_ERROR)
        return nil

    case .Paren_Right:
        parser_error(parser, PARSER_COMPILER_ERROR)
        return nil

    case .Identifier:
        return parse_identifier(parser, token)

    case .Integer:
        return parse_integer(parser, token)

    case .Unsigned_Integer:
        unimplemented()

    case .Float:
        unimplemented()

    case .Hex:
        unimplemented()

    case .Binary:
        unimplemented()

    case .Octal:
        unimplemented()

    case .String:
        unimplemented()

    case .Char:
        unimplemented()

    case .True:
        unimplemented()

    case .False:
        unimplemented()

    case .Type_Int:
        return parse_literal_type(parser, token)

    case .Type_Uint:
        return parse_literal_type(parser, token)

    case .Type_Float:
        return parse_literal_type(parser, token)

    case .Type_Bool:
        return parse_literal_type(parser, token)

    case .Type_String:
        return parse_literal_type(parser, token)

    case .Brace_Left:
        unimplemented()

    case .Brace_Right:
        unimplemented()

    case .Bracket_Left:
        unimplemented()

    case .Bracket_Right:
        unimplemented()

    case .Minus:
        return parse_binary_expr(parser, token)

    case .Plus:
        return parse_binary_expr(parser, token)

    case .Star:
        return parse_binary_expr(parser, token)

    case .Slash:
        return parse_binary_expr(parser, token)

    case .Percent:
        return parse_binary_expr(parser, token)

    case .Using:
        unimplemented()

    case .Proc:
        return parse_proc_decl(parser, token)

    case .Foreign:
        parse_foreign(parser, token)

    }

    return nil
}

parse_binary_expr :: proc(parser: ^Parser, token: Token) -> ^Op_Code {
    // not allowed in global scope
    if parser.current_context.kind == .File {
        parser_error(parser, PARSER_OPERATOR_IN_FILE_SCOPE)
    }

    op := create_op_code(parser, token)
    op.variant = Op_Binary_Expr{op=token.text}
    return op
}

parse_foreign :: proc(parser: ^Parser, token: Token) {
    if parser.current_context.proc_decl == nil {
        parser_error(parser, PARSER_FOREIGN_MISPLACED)
    }

    parser.current_context.proc_decl.is_foreign = true

    if allow(parser, .Identifier) {
        parser.current_context.proc_decl.foreign_lib = parser.prev_token
    }

    expect(parser, .Semicolon)
}

parse_proc_decl :: proc(parser: ^Parser, token: Token) -> ^Op_Code {
    result := create_op_code(parser, token)
    proc_decl := Op_Proc_Decl{}
    proc_decl.name = expect(parser, .Identifier)

    push_parsing_context(parser, .Procedure)
    parser.current_context.proc_decl = &proc_decl

    if allow(parser, .Paren_Left) && !allow(parser, .Paren_Right) {
        parse_proc_signature(parser, &proc_decl)
    }

    proc_body_loop: for !parser.error_in_context {
        if allow(parser, .Semicolon) {
            break proc_body_loop
        }

        value := parse_expression(parser)
        write_op_code(&proc_decl.body, value)
    }

    if parser.error_in_context {
        for !allow(parser, .Semicolon) && !allow(parser, .EOF) do next(parser)
        pop_parsing_context(parser)
        return nil
    }

    return_op := create_op_code(parser, parser.prev_token)
    return_op.variant = Op_Return{results=proc_decl.results[:]}
    write_op_code(&proc_decl.body, return_op)

    pop_parsing_context(parser)

    result.variant = proc_decl
    return result
}

parse_proc_signature :: proc(parser: ^Parser, proc_decl: ^Op_Proc_Decl) {
    arguments := make([dynamic]^Op_Code)
    results := make([dynamic]^Op_Code)
    IP := 0
    maybe_has_results := false

    proc_args: for {
        token := next(parser)
        #partial switch token.kind {
        case .Dash_Dash_Dash, .Paren_Right:
            maybe_has_results = token.kind == .Dash_Dash_Dash
            break proc_args
        case .Identifier:
            assert(false) // TODO(nawe) support this
        case .Type_Int, .Type_Uint, .Type_Float, .Type_Bool, .Type_String:
            op := parse_literal_type(parser, token)
            op.register = new_clone(Register{prefix="arg", ip=IP, type=op.type})
            IP += 1
            append(&arguments, op)
        case:
            parser_error(parser, PARSER_UNEXPECTED_TOKEN_IN_PROC_SIGNATURE, token.text)
            return
        }
    }

    if maybe_has_results {
        proc_results: for {
            token := next(parser)

            #partial switch token.kind {
            case .Paren_Right:
                break proc_results
            case .Type_Int, .Type_Uint, .Type_Float, .Type_Bool, .Type_String:
                append(&results, parse_literal_type(parser, token))
            case:
                parser_error(parser, PARSER_UNEXPECTED_TOKEN_IN_PROC_SIGNATURE, token.text)
                return
            }

        }
    }

    proc_decl.arguments = arguments[:]
    proc_decl.results   = results[:]
}

parse_identifier :: proc(parser: ^Parser, token: Token) -> ^Op_Code {
    // not allowed in global scope
    if parser.current_context.kind == .File {
        parser_error(parser, PARSER_IDENTIFIER_IN_FILE_SCOPE)
    }

    op := create_op_code(parser, token)
    op.variant = Op_Identifier{token}
    return op
}

parse_integer :: proc(parser: ^Parser, token: Token) -> ^Op_Code {
    op := create_op_code(parser, token)
    op.type = get_type_basic(.Int)
    value, ok := strconv.parse_i64(stanczyk_number_to_c_number(token.text))
    if !ok do parser_error(parser, PARSER_INVALID_NUMBER)
    op.value = value
    op.variant = Op_Push_Constant{}
    return op
}

parse_literal_type :: proc(parser: ^Parser, token: Token) -> ^Op_Code {
    op := create_op_code(parser, token)
    op.variant = Op_Type_Lit{}
    op.value = get_type_by_name("typeid")

    #partial switch token.kind {
    case .Type_Int:    op.type = get_type_basic(.Int)
    case .Type_Uint:   op.type = get_type_basic(.Uint)
    case .Type_Float:  op.type = get_type_basic(.Float)
    case .Type_Bool:   op.type = get_type_basic(.Bool)
    case .Type_String: op.type = get_type_basic(.String)
    }

    return op
}

stanczyk_number_to_c_number :: proc(s: string) -> string {
    b := s[len(s)-1]
    if b != '.' && !(b >= '0' && b <= '9') do return s[:len(s)-1]
    return s
}
