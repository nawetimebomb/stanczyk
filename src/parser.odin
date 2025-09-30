package main

import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:unicode/utf8"

Parser :: struct {
    file_info:  ^File_Info,

    prev_token: Token,
    curr_token: Token,
    lexer:      Lexer,
}

parser_error :: proc(token: Token, format: string, args: ..any) {
    compiler.error_reported = true
    message := fmt.aprintf(format, ..args)
    append(&compiler.errors, Compiler_Error{
        message      = message,
        token        = token,
    })

    token := compiler.parser.prev_token

    loop: for {
        #partial switch token.kind {
        case .EOF, .Semicolon: break loop
        }

        token = next()
    }
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

write_chunk :: proc(token: Token, variant: Instruction_Variant) {
    result := new(Instruction)
    result.token    = token
    result.offset   = len(compiler.current_proc.code)
    result.variant  = variant
    append(&compiler.current_proc.code, result)
}

make_procedure :: proc(token: Token) -> ^Procedure {
    result := new(Procedure)
    result.token        = token
    result.name         = token.text
    result.id           = compiler.procedure_uid
    result.file_info    = token.file_info
    result.entity       = create_entity(token, Entity_Proc{ procedure = result })
    result.scope        = create_scope(.Procedure)
    result.code         = make([dynamic]^Instruction)

    if result.name == "main" {
        compiler.main_found_at = &result.token
        compiler.main_proc_uid = result.id
    }

    compiler.procedure_uid += 1

    return result
}

stanczyk_number_to_c_number :: proc(s: string) -> string {
    if len(s) == 2 && s[0] == '-' {
        return s
    }

    b := s[len(s)-1]

    if b != '.' && !(b >= '0' && b <= '9') {
        return s[:len(s)-1]
    }

    return s
}

parse_byte_value :: proc(token: Token) -> byte {
    result: byte
    bytes := token.text[2:len(token.text)-1]

    if len(bytes) > 2 {
        parser_error(token, INVALID_BYTE_LITERAL, token.text)
        return 0
    } else if len(bytes) == 2 {
        if bytes[0] != '\\' {
            parser_error(token, INVALID_BYTE_LITERAL, token.text)
            return 0
        }

        switch bytes[1] {
        case 'a':  result = 7
        case 'b':  result = 8
        case 't':  result = 9
        case 'n':  result = 10
        case 'v':  result = 11
        case 'f':  result = 12
        case 'r':  result = 13
        case 'e':  result = 27
        case '\'': result = '\''
        }
    } else {
        result = bytes[0]
    }

    return result
}

allow :: proc(kind: Token_Kind) -> bool {
    if compiler.parser.curr_token.kind == kind {
        next()
        return true
    }
    return false
}

check :: proc(kind: Token_Kind) -> bool {
    if compiler.parser.curr_token.kind == kind {
        return true
    }
    return false
}

expect :: proc(kind: Token_Kind) -> (result: Token) {
    position_token := compiler.parser.prev_token
    result = next()

    if result.kind != kind {
        parser_error(position_token, "Expected {}, got {}", kind, result.kind)
    }

    return
}

next :: proc() -> Token {
    token := get_next_token(&compiler.parser.lexer)
    compiler.parser.prev_token = compiler.parser.curr_token
    compiler.parser.curr_token = token
    return compiler.parser.prev_token
}

can_continue_parsing :: proc() -> bool {
    result := !compiler.error_reported && !check(.EOF)

    if !result {
        // skip to the end of the procedure or the end of file, whatever is first.
        for !check(.Semicolon) && !check(.EOF) {
            next()
        }
    }

    return result
}

is_in_global_scope :: proc() -> bool {
    return compiler.current_proc == compiler.global_proc
}

find_closest_loop_scope :: proc() -> ^Scope {
    scope := compiler.current_scope

    for scope != nil {
        if scope.kind == .For_Loop {
            break
        }

        scope = scope.parent
    }

    return scope
}

parse_const_declaration :: proc() {
    name_token := expect(.Identifier)
    const := Entity_Const{}
    token := next()

    #partial switch token.kind {
    case .Identifier:
        parser_error(token, INVALID_CONST_VALUE)
        return

    case .Integer:
        value, ok := strconv.parse_i64(stanczyk_number_to_c_number(token.text))
        assert(ok, "Compiler Bug. This was an Int by the Lexer")
        const.type = type_int
        const.value = value

    case .True:
        const.type = type_bool
        const.value = true

    case .False:
        const.type = type_bool
        const.value = false

    case .Float:
        value, ok := strconv.parse_f64(stanczyk_number_to_c_number(token.text))
        assert(ok, "Compiler Bug. This was an Int by the Lexer")
        const.index = add_to_constants(value)
        const.type = type_float
        const.value = value

    case .Unsigned_Integer:
        value, ok := strconv.parse_u64(stanczyk_number_to_c_number(token.text))
        assert(ok, "Compiler Bug. This was an Int by the Lexer")
        const.type = type_uint
        const.value = value

    case .Byte:
        const.type = type_byte
        const.value = parse_byte_value(token)

    case .String:
        value := token.text[1:len(token.text)-1]
        const.index = add_to_constants(value)
        const.type = type_string
        const.value = value

    case .Format_String:
        unimplemented()

    case:
        unimplemented()
    }

    expect(.Semicolon)

    create_entity(name_token, const)
}

parse_let_declaration :: proc() {
    bindings := make([dynamic]Token, context.temp_allocator)

    for can_continue_parsing() && !check(.Semicolon) {
        token := next()

        #partial switch token.kind {
        case .Identifier:
            append(&bindings, token)

        case:
            parser_error(token, UNEXPECTED_TOKEN_LET_BIND, token.text)
            return
        }
    }

    end_token := expect(.Semicolon)

    if len(bindings) == 0 {
        parser_error(end_token, EMPTY_LET_DECL)
        return
    }

    #reverse for token in bindings {
        write_chunk(token, STORE_BIND{token=token})
    }
}

parse_var_declaration :: proc() {
    name_token := expect(.Identifier)
    type_token: Token
    use_type_token: bool
    expressions_count := 0

    if allow(.Colon) {
        type_token = expect(.Identifier)
        use_type_token = true
    }

    for can_continue_parsing() && !check(.Semicolon) {
        next_token := compiler.parser.curr_token

        #partial switch next_token.kind {
        case .Identifier, .Integer, .Unsigned_Integer, .Float, .Hex, .Binary, .Octal, .String,
            .Format_String, .Byte, .True, .False, .Minus, .Plus, .Star, .Percent, .Equal,
            .Not_Equal,  .Greater, .Greater_Equal, .Less, .Less_Equal:
            parse_expression()
            expressions_count += 1
        case:
            parser_error(next_token, INVALID_TOKEN_VAR_BODY, next_token.text)
            return
        }

    }

    end_token := expect(.Semicolon)

    if !use_type_token && expressions_count == 0 {
        parser_error(name_token, EMPTY_VAR_DECL)
        return
    }

    if is_in_global_scope() {
        write_chunk(end_token, STORE_VAR_GLOBAL{
            name_token     = name_token,
            type_token     = type_token,
            use_type_token = use_type_token,
            is_initialized = expressions_count > 0,
        })
    } else {
        write_chunk(end_token, STORE_VAR_LOCAL{
            name_token     = name_token,
            type_token     = type_token,
            use_type_token = use_type_token,
            is_initialized = expressions_count > 0,
        })
    }
}

parse_proc_declaration :: proc() {
    name_token := expect(.Identifier)
    procedure := make_procedure(name_token)

    if allow(.Paren_Left) && !allow(.Paren_Right) {
        arguments := make([dynamic]Parameter)
        results   := make([dynamic]Parameter)
        current_array := &arguments

        for can_continue_parsing() && !allow(.Paren_Right) {
            was_quoted := allow(.Quote)
            token := next()

            #partial switch token.kind {
            case .Dash_Dash_Dash:
                current_array = &results

            case .Identifier:
                name_token := token
                type_token := token

                if allow(.Colon) {
                    if was_quoted {
                        parser_error(token, UNEXPECTED_TOKEN_PROC_TYPE, fmt.tprintf("'{}", token.text))
                        return
                    }

                    was_quoted = allow(.Quote)
                    type_token = expect(.Identifier)
                }

                append(current_array, Parameter{
                    name_token = name_token,
                    type_token = type_token,
                    is_named   = name_token != type_token,
                    is_quoted  = was_quoted,
                    type       = nil,
                })

            case:
                parser_error(token, UNEXPECTED_TOKEN_PROC_TYPE, token.text)
                parser_fatal_error()
            }
        }

        procedure.arguments = arguments[:]
        procedure.results   = results[:]
    }

    if procedure.name == "main" && is_in_global_scope() {
        if len(procedure.arguments) > 0 || len(procedure.results) > 0 {
            parser_error(name_token, MAIN_PROC_TYPE_NOT_EMPTY)
        }
    }

    push_procedure(procedure)

    //for arg, index in procedure.arguments {
    //    write_chunk(arg.type_token, PUSH_ARG{index})

    //    if arg.is_named {
    //        write_chunk(arg.name_token, STORE_BIND{arg.name_token})
    //    }
    //}

    for can_continue_parsing() && !check(.Semicolon) {
        parse_expression()
    }

    // NOTE(nawe) exit early if it cannot be parsed anymore
    if !can_continue_parsing() {
        pop_procedure()
        return
    }

    return_token := expect(.Semicolon)

    if len(procedure.results) == 0 {
        write_chunk(return_token, RETURN{})
    } else if len(procedure.results) == 1 {
        write_chunk(return_token, RETURN_VALUE{})
    } else {
        write_chunk(return_token, RETURN_VALUES{})
    }

    if compiler.current_scope != compiler.current_proc.scope {
        parser_error(return_token, UNBALANCED_SCOPE)
        return
    }

    pop_procedure()

    append(&bytecode, procedure)
}

parse_struct_declaration :: proc() {
    name_token := expect(.Identifier)
    fields := make([dynamic]Type_Struct_Field, context.temp_allocator)

    for can_continue_parsing() && !check(.Semicolon) {
        field: Type_Struct_Field
        field.name_token = expect(.Identifier)
        field.name = field.name_token.text

        expect(.Colon)

        field.type_token = expect(.Identifier)
        append(&fields, field)
    }

    expect(.Semicolon)

    if len(fields) == 0 {
        parser_error(name_token, EMPTY_STRUCT_DECL)
    }

    type := new(Type)
    type.name = name_token.text
    type.variant = Type_Struct{
        fields = slice.clone(fields[:]),
    }

    if is_in_global_scope() {
        register_global_type(type)
    } else {
        create_entity(name_token, Entity_Type{type})
    }
}

parse_type_declaration :: proc() {
    name_token := expect(.Identifier)
    maybe_type_token := next()

    #partial switch maybe_type_token.kind {
    case .Proc:       unimplemented("Allow to define procedure types")
    case .Identifier:
        derived_type := compiler.types_by_name[maybe_type_token.text]

        if derived_type == nil {
            matches := find_entity(maybe_type_token.text)

            if len(matches) == 0 || len(matches) > 1 {
                parser_error(maybe_type_token, FAILED_TO_PARSE_TYPE)
                parser_fatal_error()
            }

            entity := matches[0]

            #partial switch v in entity.variant {
            case Entity_Type: derived_type = v.type
            case:
                parser_error(maybe_type_token, FAILED_TO_PARSE_TYPE)
                parser_fatal_error()
            }
        }

        type := new(Type)
        type.name = name_token.text
        type.variant = Type_Alias{
            derived = derived_type,
        }

        if is_in_global_scope() {
            register_global_type(type)
        } else {
            create_entity(name_token, Entity_Type{type})
        }
    }

    expect(.Semicolon)
}



parse_array_literal :: proc() {
    // This is something like: [1 2 3]
    unimplemented()
}

parse_struct_literal :: proc() {
    unimplemented()
}

parse_file :: proc(file_info: ^File_Info) {
    compiler.parser = new(Parser)
    compiler.parser.file_info = file_info

    init_lexer()
    next()

    for !allow(.EOF) {
        compiler.error_reported = false
        parse_expression_in_global_scope()
    }

    if len(compiler.errors) > 0 {
        parser_fatal_error()
    }

    compiler.lines_parsed += compiler.parser.lexer.line

    free(compiler.parser)
}

parse_expression_in_global_scope :: proc() {
    token := next()

    #partial switch token.kind {
    case .Const:  parse_const_declaration()
    case .Proc:   parse_proc_declaration()
    case .Type:   parse_type_declaration()
    case .Var:    parse_var_declaration()
    case .Struct: parse_struct_declaration()
    case:         parser_error(token, IMPERATIVE_EXPR_GLOBAL)
    }
}

parse_expression :: proc() {
    token := next()

    switch token.kind {
    case .EOF:
        assert(false, "Compiler Bug. EOF token should never be handled by this procedure.")

    case .Dash_Dash_Dash:
        assert(false, "Compiler Bug. This token should be handled as part of other procedures, like in proc declaration signature.")

    case .Invalid:
        parser_error(token, INVALID_TOKEN, token.text)

    case .Identifier:
        if allow(.Period) {
            subscript := next()

            if subscript.kind == .Identifier {
                write_chunk(token, PUSH_STRUCT_FIELD{
                    struct_name = token.text,
                    field_name  = subscript.text,
                })
            }
        } else {
            write_chunk(token, IDENTIFIER{token.text})
        }

    case .Integer:
        value, ok := strconv.parse_i64(stanczyk_number_to_c_number(token.text))
        assert(ok, "Compiler Bug. This was an Int by the Lexer")
        write_chunk(token, PUSH_INT{value})

    case .Unsigned_Integer:
        value, ok := strconv.parse_u64(stanczyk_number_to_c_number(token.text))
        assert(ok, "Compiler Bug. This was an Uint by the Lexer")
        write_chunk(token, PUSH_UINT{value})

    case .Float:
        value, ok := strconv.parse_f64(stanczyk_number_to_c_number(token.text))
        assert(ok, "Compiler Bug. This was a Float by the Lexer")
        index := add_to_constants(value)
        write_chunk(token, PUSH_FLOAT{index})

    case .Hex:
    case .Binary:
    case .Octal:

    case .Byte:
        write_chunk(token, PUSH_BYTE{parse_byte_value(token)})

    case .String:
        value := token.text[1:len(token.text)-1]
        index := add_to_constants(value)
        write_chunk(token, PUSH_STRING{index=index})

    case .Format_String:
        unimplemented()

    case .True:
        write_chunk(token, PUSH_BOOL{true})

    case .False:
        write_chunk(token, PUSH_BOOL{false})

    case .Period:

    case .Semicolon:
    case .Brace_Left:
        parse_struct_literal()

    case .Brace_Right:

    case .Bracket_Left:
        parse_array_literal()

    case .Bracket_Right:

    case .Paren_Left:
    case .Paren_Right:

    case .Minus:
        write_chunk(token, BINARY_MINUS{})

    case .Plus:
        write_chunk(token, BINARY_ADD{})

    case .Star:
        write_chunk(token, BINARY_MULTIPLY{})

    case .Slash:
        write_chunk(token, BINARY_DIVIDE{})

    case .Percent:
        write_chunk(token, BINARY_MODULO{})

    case .Colon:
        unimplemented()

    case .Equal:
        write_chunk(token, COMPARE_EQUAL{})

    case .Not_Equal:
        write_chunk(token, COMPARE_NOT_EQUAL{})

    case .Greater:
        write_chunk(token, COMPARE_GREATER{})

    case .Greater_Equal:
        write_chunk(token, COMPARE_GREATER_EQUAL{})

    case .Less:
        write_chunk(token, COMPARE_LESS{})

    case .Less_Equal:
        write_chunk(token, COMPARE_LESS_EQUAL{})

    case .Quote:
        this_proc := compiler.current_proc
        current_ip := len(this_proc.code)
        parse_expression()
        ins := this_proc.code[current_ip]
        ins.quoted = true

    case .Autorange_Less, .Autorange_Greater:
        if !check(.For) && !check(.For_Star) {
            parser_error(token, FOR_STATEMENT_AFTER_AUTORANGE_REQUIRED)
            return
        }

        bind_tokens := make([dynamic]Token, context.temp_allocator)

        if allow(.For_Star) {
            for can_continue_parsing() && !check(.In) && len(bind_tokens) < 3 {
                append(&bind_tokens, next())
            }

            in_token := expect(.In)
        } else {
            expect(.For)
        }

        for_scope := create_scope(.For_Loop)
        for_scope.scope_id = len(compiler.current_proc.code)
        write_chunk(token, LOOP_RANGE{
            id     = for_scope.scope_id,
            tokens = slice.clone(bind_tokens[:]),
            dir    = token.kind == .Autorange_Less ? .Inc : .Dec,
            scope  = for_scope,
        })
        push_scope(for_scope)

    case .Drop:
        write_chunk(token, DROP{})

    case .Nip:
        write_chunk(token, NIP{})

    case .Dup:
        write_chunk(token, DUP{})

    case .Dup_Star:
        write_chunk(token, DUP_PREV{})

    case .Swap:
        write_chunk(token, SWAP{})

    case .Rot:
        write_chunk(token, ROTATE_LEFT{})

    case .Rot_Star:
        write_chunk(token, ROTATE_RIGHT{})

    case .Over:
        write_chunk(token, OVER{})

    case .Tuck:
        write_chunk(token, TUCK{})

    case .Using:

    case .Foreign:

    case .Proc:
        parse_proc_declaration()

    case .Type:
        parse_type_declaration()

    case .Const:
        parse_const_declaration()

    case .Let:
        parse_let_declaration()

    case .Var:
        parse_var_declaration()

    case .Struct:
        parse_struct_declaration()

    case .Set:
        write_chunk(token, SET{})

    case .Len:
        write_chunk(token, LEN{})

    case .If:
        if_scope := create_scope(.Branch_Then)
        if_scope.scope_id = len(compiler.current_proc.code)
        write_chunk(token, IF_FALSE_JUMP{id=if_scope.scope_id, scope=if_scope})
        push_scope(if_scope)

    case .Else:
        scope := compiler.current_scope

        if scope.kind != .Branch_Then {
            parser_error(token, UNATTACHED_TO_IF, "else")
            return
        }

        scope.kind = .Branch_Else
        write_chunk(token, IF_ELSE_JUMP{id=scope.scope_id})

    case .Fi:
        scope := pop_scope(token)

        #partial switch scope.kind {
        case .Branch_Then, .Branch_Else:
        case:
            parser_error(token, UNATTACHED_TO_IF, "fi")
            return
        }

        write_chunk(token, IF_END{id=scope.scope_id})

    case .For:
        for_scope := create_scope(.For_Loop)
        for_scope.scope_id = len(compiler.current_proc.code)
        write_chunk(token, LOOP_ITERATE{
            id    = for_scope.scope_id,
            scope = for_scope,
        })
        push_scope(for_scope)

    case .For_Star:
        for_scope := create_scope(.For_Loop)
        for_scope.scope_id = len(compiler.current_proc.code)

        bind_tokens := make([dynamic]Token, context.temp_allocator)

        for can_continue_parsing() && !check(.In) && len(bind_tokens) < 3 {
            append(&bind_tokens, next())
        }

        in_token := expect(.In)

        write_chunk(token, LOOP_ITERATE{
            id     = for_scope.scope_id,
            tokens = slice.clone(bind_tokens[:]),
            scope  = for_scope,
        })
        push_scope(for_scope)

    case .In:

    case .Loop:
        scope := pop_scope(token)

        if scope.kind != .For_Loop {
            parser_error(token, UNATTACHED_TO_LOOP, "loop")
            return
        }

        write_chunk(token, LOOP_END{id=scope.scope_id})

    case .Continue:
        scope := find_closest_loop_scope()

        if scope == nil || scope.kind != .For_Loop {
            parser_error(token, UNATTACHED_TO_LOOP, "continue")
            return
        }

        write_chunk(token, LOOP_CONTINUE{id=scope.scope_id})

    case .Break:
        scope := find_closest_loop_scope()

        if scope.kind != .For_Loop {
            parser_error(token, UNATTACHED_TO_LOOP, "continue")
            return
        }

        write_chunk(token, LOOP_BREAK{id=scope.scope_id})

    case .Return:
        this_proc := compiler.current_proc

        if len(this_proc.results) == 0 {
            write_chunk(token, RETURN{})
        } else if len(this_proc.results) == 1 {
            write_chunk(token, RETURN_VALUE{})
        } else {
            write_chunk(token, RETURN_VALUES{})
        }

    case .Cast:
        write_chunk(token, CAST{})

    case .Print:
        write_chunk(token, PRINT{})
    }
}
