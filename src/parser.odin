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

Parser :: struct {
    file_info:         ^File_Info,

    prev_token:        Token,
    curr_token:        Token,
    lexer:             Lexer,
}

parser_error :: proc(token: Token, format: string, args: ..any) {
    compiler.error_reported = true
    message := fmt.aprintf(format, ..args)
    append(&compiler.errors, Compiler_Error{
        message = message,
        token   = token,
    })
}

parser_fatal_error :: proc() {
    report_all_errors()
    errors_count := len(compiler.errors)
    fatalf(
        .Parser,
        "found {} {} while parsing {}",
        errors_count,
        errors_count > 1 ? "errors" : "error",
        compiler.parser.file_info.fullpath,
    )
}

is_eof :: proc() -> bool {
    return compiler.parser.prev_token.kind == .EOF
}

create_foreign_name :: proc(parts: []string) -> string {
    VALID :: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"

    is_global_scope := compiler.current_scope == compiler.global_scope
    foreign_name_builder := strings.builder_make()

    for part, part_index in parts {
        snake_name := strings.to_snake_case(part)

        for r, index in snake_name {
            if strings.contains_rune(VALID, r) {
                strings.write_rune(&foreign_name_builder, r)
            } else {
                if index == 0 {
                    strings.write_rune(&foreign_name_builder, '_')
                }

                strings.write_int(&foreign_name_builder, int(r))
            }
        }

        if part_index < len(parts)-1 {
            strings.write_string(&foreign_name_builder, "__")
        }
    }

    return strings.to_string(foreign_name_builder)
}

create_foreign_proc_name :: proc(token: Token) -> string {
    filename := token.file_info.short_name
    stanczyk_name := token.text
    foreign_name: string

    if compiler.current_scope != compiler.global_scope {
        parts := make([dynamic]string, context.temp_allocator)
        s := compiler.current_scope

        append(&parts, filename)

        for s.op_code != nil || s != compiler.global_scope {
            if proc_scope, ok := s.op_code.variant.(Op_Proc_Decl); ok {
                append(&parts, proc_scope.name.text)
            }

            s = s.parent
        }

        append(&parts, stanczyk_name)

        foreign_name = create_foreign_name(parts[:])

    } else {
        if stanczyk_name == "main" {
            foreign_name = strings.clone("stanczyk__main")
        } else {
            foreign_name = create_foreign_name({filename, stanczyk_name})
        }
    }

    return foreign_name
}

create_op_code :: proc(token: Token) -> ^Op_Code {
    op := new(Op_Code)
    op.token = token
    op.ip = compiler.current_ip
    compiler.current_ip += 1
    return op
}

write_op_code :: proc(chunk: ^[dynamic]^Op_Code, op: ^Op_Code) {
    append(chunk, op)
}

create_scope :: proc(op_code: ^Op_Code = nil) -> ^Scope {
    new_scope := new(Scope)
    new_scope.stack = new(Stack)
    new_scope.op_code = op_code
    return new_scope
}

push_proc :: proc(proc_scope: ^Scope) {
    assert(proc_scope != nil)
    push_scope(proc_scope)
    compiler.proc_scope = proc_scope
}

pop_proc :: proc() {
    is_scope_proc :: proc(scope: ^Scope) -> bool {
        if scope.op_code != nil {
            _, is_proc := scope.op_code.variant.(Op_Proc_Decl)
            return is_proc
        }

        return false
    }

    pop_scope()

    if is_scope_proc(compiler.current_scope) {
        compiler.proc_scope = compiler.current_scope
    } else {
        compiler.proc_scope = nil
    }
}

push_scope :: proc(new_scope: ^Scope) {
    assert(new_scope != nil)
    new_scope.parent = compiler.current_scope
    compiler.current_scope = new_scope
}

pop_scope :: proc() {
    old_scope := compiler.current_scope
    compiler.current_scope = old_scope.parent
    stack_reset(old_scope.stack)
}

allow :: proc(kind: Token_Kind) -> bool {
    if compiler.parser.curr_token.kind == kind {
        next()
        return true
    }
    return false
}

expect :: proc(kind: Token_Kind) -> (token: Token) {
    token = next()

    if token.kind != kind {
        parser_error(token, "Expected {}, got {}", kind, token.kind)
        for {
            token := next()
            if token.kind == .EOF || token.kind == .Semicolon do break
        }
    }

    return
}

next :: proc() -> Token {
    token := get_next_token(&compiler.parser.lexer)
    compiler.parser.prev_token = compiler.parser.curr_token
    compiler.parser.curr_token = token
    return compiler.parser.prev_token
}

parse_file :: proc(file_info: ^File_Info) {
    compiler.parser = new(Parser)
    compiler.parser.file_info = file_info

    init_lexer()
    next()

    main_loop: for !is_eof() {
        if allow(.EOF) {
            break main_loop
        }

        compiler.error_reported = false
        op := parse_expression()
        if op == nil do break
        write_op_code(&program_bytecode, op)
    }

    if len(compiler.errors) > 0 {
        parser_fatal_error()
    }

    compiler.lines_parsed += compiler.parser.lexer.line

    free(compiler.parser)
}

parse_expression :: proc() -> ^Op_Code {
    token := next()

    switch token.kind {
    case .Invalid:
        parser_error(token, PARSER_UNEXPECTED_TOKEN, token.text)
        return nil

    case .Dash_Dash_Dash:
        parser_error(token, PARSER_UNEXPECTED_TOKEN, token.text)
        return nil

    case .EOF:
        parser_error(token, PARSER_UNEXPECTED_EOF)
        return nil

    case .Semicolon:
        parser_error(token, PARSER_COMPILER_ERROR)
        return nil

    case .Paren_Left:
        parser_error(token, PARSER_COMPILER_ERROR)
        return nil

    case .Paren_Right:
        parser_error(token, PARSER_COMPILER_ERROR)
        return nil

    case .Identifier:
        return parse_identifier(token)

    case .Integer:
        return parse_integer(token)

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

    case .Brace_Left:
        unimplemented()

    case .Brace_Right:
        unimplemented()

    case .Bracket_Left:
        unimplemented()

    case .Bracket_Right:
        unimplemented()

    case .Minus:
        return parse_binary_expr(token)

    case .Plus:
        op := create_op_code(token)
        op.variant = Op_Plus{}
        return op

    case .Star:
        return parse_binary_expr(token)

    case .Slash:
        return parse_binary_expr(token)

    case .Percent:
        return parse_binary_expr(token)

    case .Using:
        unimplemented()

    case .Proc:
        return parse_proc_decl(token)

    case .Drop:
        op := create_op_code(token)
        op.variant = Op_Drop{}
        return op

    case .Foreign:
        parse_foreign(token)

    }

    return nil
}

parse_binary_expr :: proc(token: Token) -> ^Op_Code {
    if is_global_scope() {
        parser_error(token, PARSER_OPERATOR_IN_FILE_SCOPE)
    }

    op := create_op_code(token)
    op.variant = Op_Binary_Expr{op=token.text}
    return op
}

parse_foreign :: proc(token: Token) {
    if allow(.Identifier) {
        //parser.current_context.proc_decl.foreign_lib = parser.prev_token
    }

    expect(.Semicolon)
}

parse_proc_decl :: proc(token: Token) -> ^Op_Code {
    result := create_op_code(token)
    proc_decl := Op_Proc_Decl{}
    proc_decl.name = expect(.Identifier)
    proc_decl.foreign_name = create_foreign_proc_name(proc_decl.name)
    proc_decl.entity = create_entity(proc_decl.name.text, result, Entity_Procedure{})
    proc_decl.scope  = create_scope(result)

    push_proc(proc_decl.scope)

    if allow(.Paren_Left) && !allow(.Paren_Right) {
        parse_proc_signature(&proc_decl)
    }

    proc_body_loop: for !has_error() {
        if allow(.Semicolon) {
            break proc_body_loop
        }

        value := parse_expression()
        write_op_code(&proc_decl.body, value)
    }

    if has_error() {
        for !allow(.Semicolon) && !allow(.EOF) do next()
        return nil
    }

    return_op := create_op_code(compiler.parser.prev_token)
    return_op.variant = Op_Return{results=proc_decl.results[:]}
    write_op_code(&proc_decl.body, return_op)

    result.variant = proc_decl
    pop_proc()
    return result
}

parse_proc_signature :: proc(proc_decl: ^Op_Proc_Decl) {
    arguments := make([dynamic]^Op_Code)
    results := make([dynamic]^Op_Code)
    IP := 0
    maybe_has_results := false

    proc_args: for {
        token := next()

        #partial switch token.kind {
        case .Dash_Dash_Dash, .Paren_Right:
            maybe_has_results = token.kind == .Dash_Dash_Dash
            break proc_args
        case .Identifier:
            op := parse_identifier(token)
            op.register = new_clone(Register{prefix=ARGUMENT_PREFIX, ip=IP, type=op.type})
            append(&arguments, op)
            IP += 1
        case:
            parser_error(token, PARSER_UNEXPECTED_TOKEN_IN_PROC_SIGNATURE, token.text)
            return
        }
    }

    if maybe_has_results {
        proc_results: for {
            token := next()

            #partial switch token.kind {
            case .Paren_Right:
                break proc_results
            case .Identifier:
                append(&results, parse_identifier(token))
            case:
                parser_error(token, PARSER_UNEXPECTED_TOKEN_IN_PROC_SIGNATURE, token.text)
                return
            }
        }
    }

    proc_decl.arguments = arguments[:]
    proc_decl.results   = results[:]
}

parse_identifier :: proc(token: Token) -> ^Op_Code {
    // not allowed in global scope
    if is_global_scope() {
        parser_error(token, PARSER_IDENTIFIER_IN_FILE_SCOPE)
    }

    matches := find_entity(token.text)
    op := create_op_code(token)

    if len(matches) == 1 {
        entity := matches[0]

        switch variant in entity.variant {
        case Entity_Builtin:
            proc_call := Op_Proc_Call{}
            proc_call.foreign_name = variant.foreign_name
            proc_call.entity = entity
            op.variant = proc_call
        case Entity_Procedure:
            proc_decl := entity.op_code.variant.(Op_Proc_Decl)
            proc_call := Op_Proc_Call{}
            proc_call.foreign_name = proc_decl.foreign_name
            proc_call.entity = entity
            op.variant = proc_call

        case Entity_Type:
            op.type = variant.type
            op.variant = Op_Identifier{token}
        }
    } else {
        op.variant = Op_Identifier{token}
    }

    return op
}

parse_integer :: proc(token: Token) -> ^Op_Code {
    op := create_op_code(token)
    value, ok := strconv.parse_i64(stanczyk_number_to_c_number(token.text))
    if !ok do parser_error(token, PARSER_INVALID_NUMBER)
    op.value = value
    op.type  = compiler.basic_types[.Int]
    op.variant = Op_Constant{}
    return op
}

stanczyk_number_to_c_number :: proc(s: string) -> string {
    b := s[len(s)-1]
    if b != '.' && !(b >= '0' && b <= '9') do return s[:len(s)-1]
    return s
}
