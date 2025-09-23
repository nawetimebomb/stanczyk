package main

import "core:fmt"
import "core:strconv"
import "core:strings"
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
    result.id           = compiler.foreign_name_uid
    result.file_info    = token.file_info
    result.entity       = create_entity(token, Entity_Proc{ procedure = result })
    result.scope        = create_scope(.Procedure)
    result.code         = make([dynamic]^Instruction)

    if result.name == "main" {
        compiler.main_found_at = &result.token
        compiler.main_proc_uid = result.id
    }

    compiler.foreign_name_uid += 1

    return result
}

stanczyk_number_to_c_number :: proc(s: string) -> string {
    b := s[len(s)-1]
    if b != '.' && !(b >= '0' && b <= '9') do return s[:len(s)-1]
    return s
}

parse_byte_value :: proc(token: Token) -> byte {
    result: byte
    bytes := token.text[1:len(token.text)-1]

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

parse_const_declaration :: proc() {
    name_token := expect(.Identifier)
    const := Entity_Const{}
    token := next()

    #partial switch token.kind {
    case .Identifier:
        parser_error(token, INVALID_CONST_VALUE)
        return

    case .Byte:
        const.type = type_byte
        const.value = parse_byte_value(token)

    case .Integer:
        value, ok := strconv.parse_i64(stanczyk_number_to_c_number(token.text))
        assert(ok, "Compiler Bug. This was an Int by the Lexer")
        const.type = type_int
        const.value = value

    case .String:
        const.type = type_string
        const.value = token.text[1:len(token.text)-1]

    case .True:
        const.type = type_bool
        const.value = true

    case .False:
        const.type = type_bool
        const.value = false

    case .Float:
        value, ok := strconv.parse_f64(stanczyk_number_to_c_number(token.text))
        assert(ok, "Compiler Bug. This was an Int by the Lexer")
        const.type = type_float
        const.value = value

    case .Unsigned_Integer:
        value, ok := strconv.parse_u64(stanczyk_number_to_c_number(token.text))
        assert(ok, "Compiler Bug. This was an Int by the Lexer")
        const.type = type_uint
        const.value = value

    case:
        unimplemented()
    }

    expect(.Semicolon)

    const.index = add_to_constants(const.value)

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

    write_chunk(name_token, DECLARE_VAR_START{name_token})

    for can_continue_parsing() && !check(.Semicolon) {
        next_token := compiler.parser.curr_token

        #partial switch next_token.kind {
        case .Identifier, .Integer, .Unsigned_Integer, .Float, .Hex, .Binary, .Octal, .String,
            .Byte, .True, .False, .Minus, .Plus, .Star, .Percent, .Equal, .Not_Equal, .Greater,
            .Greater_Equal, .Less, .Less_Equal:
            parse_expression()
        case:
            parser_error(next_token, INVALID_TOKEN_VAR_BODY, next_token.text)
            return
        }

    }

    end_token := expect(.Semicolon)
    write_chunk(end_token, DECLARE_VAR_END{name_token})
}

parse_proc_declaration :: proc() {
    name_token := expect(.Identifier)
    procedure := make_procedure(name_token)

    if allow(.Paren_Left) && !allow(.Paren_Right) {
        arguments := make([dynamic]Parameter)
        results   := make([dynamic]Parameter)
        current_array := &arguments

        for can_continue_parsing() && !allow(.Paren_Right) {
            token := next()

            #partial switch token.kind {
            case .Dash_Dash_Dash:
                current_array = &results

            case .Identifier:
                name_token := token
                type_token := token

                if allow(.Colon) {
                    type_token = expect(.Identifier)
                }

                append(current_array, Parameter{
                    name_token = name_token,
                    type_token = type_token,
                    is_named   = name_token != type_token,
                    type       = compiler.types[type_token.text],
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

    pop_procedure()

    append(&bytecode, procedure)
}

parse_type_declaration :: proc() {
    name_token := expect(.Identifier)
    maybe_type_token := next()

    #partial switch maybe_type_token.kind {
    case .Proc:       unimplemented("Allow to define procedure types")
    case .Identifier:
        derived_type := compiler.types[maybe_type_token.text]

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
    case .Const: parse_const_declaration()
    case .Proc:  parse_proc_declaration()
    case .Type:  parse_type_declaration()
    case .Var:   parse_var_declaration()
    case:        parser_error(token, IMPERATIVE_EXPR_GLOBAL)
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
        write_chunk(token, IDENTIFIER{token.text})

    case .Integer:
        value, ok := strconv.parse_i64(stanczyk_number_to_c_number(token.text))
        assert(ok, "Compiler Bug. This was an Int by the Lexer")
        index := add_to_constants(value)
        write_chunk(token, PUSH_INT{index})

    case .Unsigned_Integer:
        value, ok := strconv.parse_u64(stanczyk_number_to_c_number(token.text))
        assert(ok, "Compiler Bug. This was an Uint by the Lexer")
        index := add_to_constants(value)
        write_chunk(token, PUSH_UINT{index})

    case .Float:
        value, ok := strconv.parse_f64(stanczyk_number_to_c_number(token.text))
        assert(ok, "Compiler Bug. This was a Float by the Lexer")
        index := add_to_constants(value)
        write_chunk(token, PUSH_FLOAT{index})

    case .Hex:
    case .Binary:
    case .Octal:
    case .String:
        index := add_to_constants(token.text[1:len(token.text)-1])
        write_chunk(token, PUSH_STRING{index=index})

    case .Byte:
        index := add_to_constants(parse_byte_value(token))
        write_chunk(token, PUSH_BYTE{index})

    case .True:
        write_chunk(token, PUSH_BOOL{true})

    case .False:
        write_chunk(token, PUSH_BOOL{false})

    case .Semicolon:
    case .Brace_Left:
    case .Brace_Right:
    case .Bracket_Left:
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

    case .Set:
        write_chunk(token, STORE_VAR{})

    case .If:
        if_scope := create_scope(.If, len(compiler.current_proc.code))
        write_chunk(token, IF_FALSE_JUMP{jump_offset=-1, local_scope=if_scope})
        push_scope(if_scope)

    case .Else:
        old_scope := pop_scope()

        if old_scope.kind != .If {
            parser_error(token, UNATTACHED_TO_IF, "else")
            return
        }

        else_scope := create_scope(.If_Else, len(compiler.current_proc.code))
        write_chunk(token, IF_ELSE_JUMP{jump_offset=-1, local_scope=else_scope})
        push_scope(else_scope)

    case .Fi:
        old_scope := pop_scope()

        if old_scope.kind != .If && old_scope.kind != .If_Else {
            parser_error(token, UNATTACHED_TO_IF, "fi")
            return
        }

        write_chunk(token, IF_END{})

    case .Cast:
        write_chunk(token, CAST{})

    case .Print:
        write_chunk(token, PRINT{})
    }
}
