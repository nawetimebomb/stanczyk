package main

import "core:fmt"
import "core:strconv"
import "core:strings"

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

create_foreign_name_from_token :: proc(token: Token) -> string {
    filename := token.file_info.short_name
    stanczyk_name := token.text
    foreign_name: string

    if compiler.current_scope != compiler.global_scope {
        parts := make([dynamic]string, context.temp_allocator)
        curr_proc := compiler.curr_proc

        append(&parts, filename)

        for curr_proc != nil {
            append(&parts, curr_proc.name)
            curr_proc = curr_proc.parent
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

add_to_registers :: proc(type: ^Type) -> ^Register {
    result := new(Register)
    result.index = len(compiler.curr_proc.registers)
    result.type = type
    append(&compiler.curr_proc.registers, result)
    return result
}

write_chunk :: proc(token: Token, variant: Instruction_Variant) {
    result := new(Instruction)
    result.token    = token
    result.offset   = len(compiler.curr_proc.code)
    result.variant  = variant
    append(&compiler.curr_proc.code, result)
}

make_procedure :: proc(token: Token) -> ^Procedure {
    result := new(Procedure)
    result.token        = token
    result.name         = token.text
    result.foreign_name = create_foreign_name_from_token(token)
    result.is_global    = is_in_global_scope()
    result.file_info    = token.file_info
    result.entity       = create_entity(result.name, Entity_Procedure{ procedure = result })
    result.scope        = create_scope()
    result.registers    = make([dynamic]^Register)
    result.code         = make([dynamic]^Instruction)
    return result
}

stanczyk_number_to_c_number :: proc(s: string) -> string {
    b := s[len(s)-1]
    if b != '.' && !(b >= '0' && b <= '9') do return s[:len(s)-1]
    return s
}

allow :: proc(kind: Token_Kind) -> bool {
    if compiler.parser.curr_token.kind == kind {
        next()
        return true
    }
    return false
}

peek :: proc(kind: Token_Kind) -> bool {
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
    result := !compiler.error_reported && !peek(.EOF)

    if !result {
        // skip to the end of the procedure or the end of file, whatever is first.
        for !peek(.Semicolon) && !peek(.EOF) {
            next()
        }
    }

    return result
}

is_in_global_scope :: proc() -> bool {
    return compiler.current_scope == compiler.global_scope
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
    case .Proc: parse_proc_declaration()
    case .Type: parse_type_declaration()
    case:       parser_error(token, IMPERATIVE_EXPR_GLOBAL)
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
            token := next()

            #partial switch token.kind {
            case .Dash_Dash_Dash:
                current_array = &results

            case .Identifier:
                name_token := token
                type_token := token

                if allow(.Colon) {
                    type_token = compiler.parser.prev_token
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

    for arg, index in procedure.arguments {
        if arg.is_named {
            // TODO(nawe) push arguments, save bound arguments
            unimplemented()
        } else {
            write_chunk(arg.type_token, PUSH_ARG{index})
        }
    }

    for can_continue_parsing() && !peek(.Semicolon) {
        parse_expression()
    }

    return_token := expect(.Semicolon)

    if len(procedure.results) == 0 {
        write_chunk(return_token, RETURN{})
    } else if len(procedure.results) == 1 {
        write_chunk(return_token, RETURN_VALUE{-1})
    } else {
        write_chunk(return_token, RETURN_VALUES{
            value = make([]^Register, len(procedure.results)),
        })
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
        type.foreign_name = create_foreign_name_from_token(name_token)
        type.variant = Type_Alias{
            derived = derived_type,
        }

        if is_in_global_scope() {
            register_global_type(type)
        } else {
            create_entity(type.name, Entity_Type{type})
        }
    }

    expect(.Semicolon)
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
        matches := find_entity(token.text)

        if len(matches) == 0 {
            write_chunk(token, IDENTIFIER{token.text})
        } else if len(matches) == 1 {
            entity := matches[0]

            switch variant in entity.variant {
            case Entity_Procedure:
                write_chunk(token, INVOKE_PROC{
                    procedure = variant.procedure,
                })
            case Entity_Type:
                write_chunk(token, PUSH_TYPE{variant.type})
            }

        } else {
            unimplemented()
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
        write_chunk(token, PUSH_FLOAT{value})

    case .Hex:
    case .Binary:
    case .Octal:
    case .String:
    case .Char:
    case .True:
    case .False:
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
        write_chunk(token, BINARY_SLASH{})

    case .Percent:
        write_chunk(token, BINARY_MODULO{})

    case .Colon:

    case .Drop:
        write_chunk(token, DROP{})

    case .Dup:
        write_chunk(token, DUP{})

    case .Using:

    case .Foreign:

    case .Proc:
        parse_proc_declaration()

    case .Type:
        parse_type_declaration()

    case .Cast:
        write_chunk(token, CAST{})

    case .Print:
        write_chunk(token, PRINT{})
    }
}
