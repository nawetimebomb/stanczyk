package main

import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:strings"

CHECKER_MISMATCHED_TYPE :: "Binary operation between different types is not allowed {}({}) vs {}({})."
CHECKER_MISSING_IDENTIFIER_DECLARATION :: "We could not find the meaning of identifier '{}'."
CHECKER_NOT_ENOUGH_VALUES_IN_STACK :: "Not enough stack values to make this operation."
CHECKER_NOT_A_NUMBER :: "We could not parse number."
CHECKER_TYPES_NOT_ALLOWED_IN_OPERATION :: "The types of elements in the stack can not be used in the following operation ({} {} {})."

Entity_Builtin_Kind :: enum u8 {
    Print   = 0,
    Println = 1,
}

Checker :: struct {
    need_to_wait_for_declarations: bool,
    missing_declarations:          [dynamic]Token,

    errors:           [dynamic]Compiler_Error,
    error_in_context: bool,
    scope:            ^Scope,
    global_scope:     ^Scope,

    global_ip:        int,
    to_parse:         [dynamic]^Op_Code,
}

Scope :: struct {
    ast:      ^Ast,
    entities: [dynamic]^Entity,
    stack:    ^Stack,
    parent:   ^Scope,
}

Stack :: struct {
    values: [dynamic]^Ast,
}

Entity :: struct {
    ast:     ^Ast,
    name:    string,
    token:   Token,
    variant: Entity_Variant,
}

Entity_Variant :: union {
    Entity_Builtin,
    Entity_Procedure,
}

Entity_Builtin :: struct {
    kind: Entity_Builtin_Kind,
}

Entity_Procedure :: struct {}

checker_error :: proc(checker: ^Checker, token: Token, format: string, args: ..any) {
    checker.error_in_context = true
    message := fmt.aprintf(format, ..args)
    append(&checker.errors, Compiler_Error{
        message = message,
        token   = token,
    })
}

checker_fatal_error :: proc(checker: ^Checker) {
    report_all_errors(checker.errors[:])
    errors_count := len(checker.errors)
    fatalf(
        .Checker, "found {} {} while doing type checking.",
        errors_count, errors_count > 1 ? "errors" : "error",
    )
}

add_missing_declaration_token :: proc(checker: ^Checker, token: Token) {
    for other in checker.missing_declarations {
        if other == token do return
    }

    append(&checker.missing_declarations, token)
}

stack_push :: proc(checker: ^Checker, stack: ^Stack, value: ^Ast) {
    append(&stack.values, value)
}

stack_pop :: proc(checker: ^Checker, stack: ^Stack, token: Token) -> ^Ast {
    value, ok := pop_safe(&stack.values)

    if !ok {
        checker_error(
            checker, token, CHECKER_NOT_ENOUGH_VALUES_IN_STACK,
        )
        checker_fatal_error(checker)
    }

    return value
}

stack_reset :: proc(checker: ^Checker, stack: ^Stack) {
    clear(&stack.values)
}

scope_create :: proc(checker: ^Checker, ast: ^Ast = nil) -> ^Scope {
    new_scope := new(Scope)
    new_scope.stack = new(Stack)
    new_scope.ast = ast
    return new_scope
}

scope_push :: proc(checker: ^Checker, new_scope: ^Scope) {
    assert(new_scope != nil)
    new_scope.parent = checker.scope
    checker.scope = new_scope
}

scope_pop :: proc(checker: ^Checker) {
    old_scope := checker.scope
    checker.scope = old_scope.parent
    stack_reset(checker, old_scope.stack)
}



compile_time_binary_operation :: proc(checker: ^Checker, lhs, rhs: ^Ast, token: Token) -> ^Ast {
    result := new(Ast)
    result.type = lhs.type
    result.token = token
    result.variant = Ast_Basic_Literal{token}

    switch token.text {
    case "+":
        #partial switch v in lhs.value {
        case f64: result.value = v + rhs.value.(f64)
        case i64: result.value = v + rhs.value.(i64)
        case u64: result.value = v + rhs.value.(u64)
        case:
            checker_error(
                checker, token, CHECKER_TYPES_NOT_ALLOWED_IN_OPERATION,
                lhs.token.text, token.text, rhs.token.text,
            )
        }
    case:
        unimplemented()
    }

    return result
}



create_foreign_name :: proc(checker: ^Checker, parts: []string) -> string {
    VALID :: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"

    is_global_scope := checker.scope == checker.global_scope
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

create_foreign_proc_name :: proc(checker: ^Checker, token: Token, stanczyk_name: string) -> string {
    foreign_name: string
    filename := token.file_info.short_name

    if checker.scope != checker.global_scope {
        if proc_scope, ok := checker.scope.ast.variant.(Ast_Proc_Decl); ok {
            foreign_name = create_foreign_name(checker, {filename, proc_scope.name, stanczyk_name})
        } else {
            foreign_name = create_foreign_name(checker, {filename, stanczyk_name})
        }
    } else {
        if stanczyk_name == "main" {
            foreign_name = strings.clone("stanczyk__main")
        } else {
            foreign_name = create_foreign_name(checker, {filename, stanczyk_name})
        }
    }

    return foreign_name
}

create_entity :: proc(checker: ^Checker, name: string, ast: ^Ast, variant: Entity_Variant) -> ^Entity {
    entity := new(Entity)
    entity.ast = ast
    entity.name = name
    entity.variant = variant

    append(&checker.scope.entities, entity)
    return entity
}

find_entity :: proc(checker: ^Checker, name: string, deep_search := true) -> []^Entity {
    result := make([dynamic]^Entity, context.temp_allocator)

    scope := checker.scope
    for scope != nil {
        for ent in scope.entities {
            if ent.name == name {
                append(&result, ent)
            }
        }

        if !deep_search do break
        scope = scope.parent
    }

    return result[:]
}



check_program_bytecode :: proc() {
    checker := new(Checker)
    checker.global_scope = scope_create(checker)
    scope_push(checker, checker.global_scope)

    checker.to_parse = slice.clone_to_dynamic(program_bytecode[:])

    create_entity(checker, "print",   nil, Entity_Builtin{.Print})
    create_entity(checker, "println", nil, Entity_Builtin{.Println})

    for len(checker.to_parse) > 0 {
        op := pop_front(&checker.to_parse)
        checker.error_in_context = false
        checker.need_to_wait_for_declarations = false
        checker.global_ip = op.local_ip
        ast := check_op(checker, op)

        if ast != nil {
            append(&program_ast, ast)
        }

        if checker.need_to_wait_for_declarations && len(checker.to_parse) == 1 {
            break
        }
    }

    for token in checker.missing_declarations {
        checker_error(
            checker, token, CHECKER_MISSING_IDENTIFIER_DECLARATION, token.text,
        )
    }

    scope_pop(checker)

    if len(checker.errors) > 0 {
        checker_fatal_error(checker)
    }

    assert(checker.scope == nil)
}



check_op :: proc(checker: ^Checker, op: ^Op_Code) -> ^Ast {
    switch variant in op.variant {
    case Op_Proc_Decl:
        // NOTE(nawe) special case that always saves to the program_ast, even if
        // it was part of the body of another procedure, this makes it easier
        // to write on any backend, and Stanczyk will only know about this symbol
        // from outside the current scope anyways.
        proc_ast := check_proc_decl(checker, op)
        append(&program_ast, proc_ast)
        return nil

    case Op_Identifier:
        return check_identifier(checker, op)
    case Op_Basic_Literal:
        check_basic_literal(checker, op)
        return nil
    case Op_Type: unimplemented()
    case Op_Binary:
        return check_binary(checker, op)

    case Op_Print: unimplemented()
    case Op_Return: //unimplemented()
    }

    return nil
}

check_basic_literal :: proc(checker: ^Checker, op: ^Op_Code) {
    parse_stanczyk_number :: proc(s: string) -> string {
        b := s[len(s)-1]
        if b != '.' && !(b >= '0' && b <= '9') do return s[:len(s)-1]
        return s
    }

    result := new(Ast)
    token := op.token
    result.token = token
    result.variant = Ast_Basic_Literal{token}

    #partial switch op.token.kind {
    case .Integer:
        result.type = get_type_basic(.Int)
        value, ok := strconv.parse_i64(parse_stanczyk_number(token.text))
        if !ok do checker_error(checker, token, CHECKER_NOT_A_NUMBER)
        result.value = value
    case .Float:
        result.type = get_type_basic(.Float)
        value, ok := strconv.parse_f64(parse_stanczyk_number(token.text))
        if !ok do checker_error(checker, token, CHECKER_NOT_A_NUMBER)
        result.value = value
    case: unimplemented()
    }

    stack_push(checker, checker.scope.stack, result)
}

check_binary :: proc(checker: ^Checker, op: ^Op_Code) -> ^Ast {
    token := op.token
    v2 := stack_pop(checker, checker.scope.stack, op.token)
    v1 := stack_pop(checker, checker.scope.stack, op.token)

    if !types_are_equal(v1.type, v2.type) {
        // TODO(nawe) improve error
        checker_error(
            checker, token, CHECKER_MISMATCHED_TYPE,
            v1.token.text, type_to_string(v1.type),
            v2.token.text, type_to_string(v2.type),
        )
        return nil
    }

    if values_are_literal(v1, v2) {
        value := compile_time_binary_operation(checker, v1, v2, token)
        stack_push(checker, checker.scope.stack, value)
        return nil
    }

    result := new(Ast)
    result.token = token
    binary_op := op.variant.(Op_Binary)
    operator := binary_op.operator.text
    variant := Ast_Binary{op = operator}

    switch operator {
    case "+":
        variant.lhs = v1
        variant.rhs = v2
    }

    result.variant = variant
    return result
}

check_block :: proc(checker: ^Checker, ops: []^Op_Code) -> ^Ast {
    result := new(Ast)
    block: Ast_Block

    if len(ops) > 0 {
        block.open  = ops[0].token
        block.close = ops[len(ops)-1].token

        for op in ops {
            if checker.error_in_context do break
            ast := check_op(checker, op)
            if ast != nil {
                append(&block.body, ast)
            }
        }
    }

    result.variant = block
    return result
}

check_identifier :: proc(checker: ^Checker, op: ^Op_Code) -> ^Ast {
    matches := find_entity(checker, op.token.text, true)

    if len(matches) == 0 {
        checker.need_to_wait_for_declarations = true
        add_missing_declaration_token(checker, op.token)
        return nil
    } else if len(matches) == 1 {
        entity := matches[0]

        switch variant in entity.variant {
        case Entity_Builtin:
            switch variant.kind {
            case .Print, .Println:
                kind := variant.kind
                v1 := stack_pop(checker, checker.scope.stack, op.token)
                arguments := make([dynamic]^Ast)
                append(&arguments, v1)
                result := new(Ast)
                result.token = op.token
                result.variant = Ast_Builtin{
                    cname = fmt.aprintf(
                        "{}_{}",
                        kind == .Print ? "print" : "println",
                        type_to_string(v1.type),
                    ),
                    arguments = arguments[:],
                }
                return result
            }

        case Entity_Procedure:
            unimplemented()
        }
    }

    // find closest match
    checker.need_to_wait_for_declarations = true
    add_missing_declaration_token(checker, op.token)
    return nil
}



check_proc_decl :: proc(checker: ^Checker, op: ^Op_Code) -> ^Ast {
    result := op.ast
    op_proc := op.variant.(Op_Proc_Decl)

    if result == nil {
        result = new(Ast)
        result.token = op.token
        result.variant = Ast_Proc_Decl{}
    }

    proc_decl := &result.variant.(Ast_Proc_Decl)
    proc_decl.name = op_proc.name.text
    proc_decl.cname = create_foreign_proc_name(checker, op.token, proc_decl.name)

    if proc_decl.entity == nil {
        matches := find_entity(checker, proc_decl.name, false)

        if len(matches) == 0 {
            proc_decl.entity = create_entity(checker, proc_decl.name, result, Entity_Procedure{})
        } else if len(matches) == 1 {
            proc_decl.entity = matches[0]
        } else {
            fmt.println(matches)
            // find the matching entity or create
            unimplemented()
        }
    }

    if proc_decl.scope == nil {
        proc_decl.scope = scope_create(checker, result)
    }

    scope_push(checker, proc_decl.scope)

    proc_decl.body = check_block(checker, op_proc.body[:])

    scope_pop(checker)

    // This should only happen if we cannot complete AST generation because we don't know
    // about some identifiers, types or the like
    if checker.need_to_wait_for_declarations {
        block := &proc_decl.body.variant.(Ast_Block)
        for x in block.body do free(x)
        free(proc_decl.body)
        delete(proc_decl.cname)

        if checker.scope == checker.global_scope {
            append(&checker.to_parse, op)
        }
        return nil
    }

    assert(proc_decl.entity != nil)
    assert(proc_decl.scope != nil)
    return result
}
