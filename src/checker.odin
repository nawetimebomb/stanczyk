package main

import "core:fmt"
import "core:strings"

CHECKER_MISMATCHED_TYPE_PROC_ARGS :: "Mismatched types in procedure arguments. Expected {}, got {}."
CHECKER_MISMATCHED_TYPE :: "Binary operation between different types is not allowed {} vs {}."
CHECKER_MISSING_IDENTIFIER_DECLARATION :: "We could not find the meaning of identifier '{}'."
CHECKER_NOT_ENOUGH_VALUES_IN_STACK :: "Not enough stack values to make this operation."
CHECKER_NOT_A_NUMBER :: "We could not parse number."
CHECKER_TYPES_NOT_ALLOWED_IN_OPERATION :: "The types of elements in the stack can not be used in the following operation ({} {} {})."

Checker :: struct {
    errors:           [dynamic]Compiler_Error,
    error_reported:   bool,

    scope:            ^Scope,
    global_scope:     ^Scope,
    proc_scope:       ^Scope,
}

Scope :: struct {
    op_code:  ^Op_Code,
    entities: [dynamic]^Entity,
    stack:    ^Stack,
    parent:   ^Scope,
}

Stack :: struct {
    values: [dynamic]^Op_Code,
}

Entity :: struct {
    op_code: ^Op_Code,
    name:    string,
    variant: Entity_Variant,
}

Entity_Variant :: union {
    Entity_Builtin,
    Entity_Procedure,
}

Entity_Builtin :: struct {
    cname:     string,
    arguments: []^Type,
    results:   []^Type,
}

Entity_Procedure :: struct {}

checker_error :: proc(checker: ^Checker, token: Token, format: string, args: ..any) {
    checker.error_reported = true
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

create_scope :: proc(checker: ^Checker, op_code: ^Op_Code = nil) -> ^Scope {
    new_scope := new(Scope)
    new_scope.stack = new(Stack)
    new_scope.op_code = op_code
    return new_scope
}

push_proc :: proc(checker: ^Checker, proc_scope: ^Scope) {
    assert(proc_scope != nil)
    push_scope(checker, proc_scope)
    checker.proc_scope = proc_scope
}

pop_proc :: proc(checker: ^Checker) {
    is_scope_proc :: proc(scope: ^Scope) -> bool {
        if scope.op_code != nil {
            _, is_proc := scope.op_code.variant.(Op_Proc_Decl)
            return is_proc
        }

        return false
    }

    pop_scope(checker)

    if is_scope_proc(checker.scope) {
        checker.proc_scope = checker.scope
    } else {
        checker.proc_scope = nil
    }
}

push_scope :: proc(checker: ^Checker, new_scope: ^Scope) {
    assert(new_scope != nil)
    new_scope.parent = checker.scope
    checker.scope = new_scope
}

pop_scope :: proc(checker: ^Checker) {
    old_scope := checker.scope
    checker.scope = old_scope.parent
    stack_reset(checker, old_scope.stack)
}


stack_reset :: proc(checker: ^Checker, stack: ^Stack) {
    clear(&stack.values)
}

stack_push :: proc(checker: ^Checker, stack: ^Stack, op: ^Op_Code) {
    if op.register == nil {
        op.register = add_register(checker, op.type)
    }

    append(&stack.values, op)
}

stack_pop :: proc(checker: ^Checker, stack: ^Stack, token: Token) -> ^Op_Code {
    value, ok := pop_safe(&stack.values)

    if !ok {
        checker_error(checker, token, CHECKER_NOT_ENOUGH_VALUES_IN_STACK)
        checker_fatal_error(checker)
    }

    return value
}

add_register :: proc(checker: ^Checker, type: ^Type, prefix := REGISTER_PREFIX) -> ^Register {
    assert(checker.proc_scope != nil)
    proc_op := &checker.proc_scope.op_code.variant.(Op_Proc_Decl)
    IP := 0

    if _, exists := proc_op.registers[type]; exists {
        IP = len(proc_op.registers[type])
    } else {
        proc_op.registers[type] = make([dynamic]Register)
    }

    append(&proc_op.registers[type], Register{prefix=prefix, ip=IP, type=type})
    return &proc_op.registers[type][IP]
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
        parts := make([dynamic]string, context.temp_allocator)
        s := checker.scope

        append(&parts, filename)

        for s.op_code != nil || s != checker.global_scope {
            if proc_scope, ok := s.op_code.variant.(Op_Proc_Decl); ok {
                append(&parts, proc_scope.name.text)
            }

            s = s.parent
        }

        append(&parts, stanczyk_name)

        foreign_name = create_foreign_name(checker, parts[:])

    } else {
        if stanczyk_name == "main" {
            foreign_name = strings.clone("stanczyk__main")
        } else {
            foreign_name = create_foreign_name(checker, {filename, stanczyk_name})
        }
    }

    return foreign_name
}


create_entity :: proc(checker: ^Checker, name: string, op: ^Op_Code, variant: Entity_Variant) -> ^Entity {
    entity := new(Entity)
    entity.op_code = op
    entity.name    = name
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
    checker.global_scope = create_scope(checker)
    push_scope(checker, checker.global_scope)

    create_entity(checker, "print", nil, Entity_Builtin{
        cname = "internal_print",
        arguments = {get_type_basic(.Int)},
    })

    for op in program_bytecode {
        check_create_entities(checker, op)
    }

    assert(checker.scope == checker.global_scope)

    for op in program_bytecode {
        checker.error_reported = false
        check_op(checker, op)
    }

    pop_scope(checker)
    assert(checker.scope == nil)

    if len(checker.errors) > 0 {
        checker_fatal_error(checker)
    }
}

check_create_entities :: proc(checker: ^Checker, op: ^Op_Code) {
    #partial switch &variant in op.variant {
    case Op_Proc_Decl:
        name := variant.name.text
        variant.cname  = create_foreign_proc_name(checker, op.token, name)
        variant.entity = create_entity(checker, name, op, Entity_Procedure{})
        variant.scope  = create_scope(checker, op)

        push_proc(checker, variant.scope)
        for child in variant.body {
            check_create_entities(checker, child)
        }
        pop_proc(checker)
    }
}

check_op :: proc(checker: ^Checker, op: ^Op_Code) {
    switch variant in op.variant {
    case Op_Identifier:
        check_identifier(checker, op)

    case Op_Constant:
        stack_push(checker, checker.scope.stack, op)
    case Op_Proc_Call:
        // maybe not needed?
    case Op_Return:
        check_return(checker, op)

    case Op_Proc_Decl:
        check_proc_decl(checker, op)

    case Op_Type_Lit:

    case Op_Binary_Expr:
        check_binary_expr(checker, op)

    case Op_Drop:
        stack_pop(checker, checker.scope.stack, op.token)
    }
}

check_binary_expr :: proc(checker: ^Checker, op: ^Op_Code) {
    binary_op := &op.variant.(Op_Binary_Expr)
    v2 := stack_pop(checker, checker.scope.stack, op.token)
    v1 := stack_pop(checker, checker.scope.stack, op.token)

    op.type = v1.type
    binary_op.lhs = v1.register
    binary_op.rhs = v2.register

    stack_push(checker, checker.scope.stack, op)
}

check_identifier :: proc(checker: ^Checker, op: ^Op_Code) {
    _stack_checks_failed :: proc(checker: ^Checker, token: Token, stack: ^Stack, params: []^Type) -> bool {
        if len(stack.values) < len(params) {
            checker_error(checker, token, CHECKER_NOT_ENOUGH_VALUES_IN_STACK)
            return true
        }
        stack_needed := stack.values[len(stack.values) - len(params):]

        for index in 0..<len(stack_needed) {
            stack_value := stack_needed[index]
            arg_type := params[index]

            if !types_are_equal(stack_value.type, arg_type) {
                checker_error(
                    checker, token, CHECKER_MISMATCHED_TYPE_PROC_ARGS,
                    type_to_string(arg_type), type_to_string(stack_value.type),
                )
                return true
            }
        }

        return false
    }

    name := op.variant.(Op_Identifier).value.text
    matches := find_entity(checker, name, true)

    if len(matches) == 0 {
        checker_error(
            checker, op.token,
            CHECKER_MISSING_IDENTIFIER_DECLARATION, name,
        )
        return
    } else if len(matches) == 1 {
        entity := matches[0]
        stack := checker.scope.stack

        switch variant in entity.variant {
        case Entity_Builtin:
            proc_call := Op_Proc_Call{}
            proc_call.cname = variant.cname
            proc_call.entity = entity

            if _stack_checks_failed(checker, op.token, stack, variant.arguments) {
                return
            }

            if len(variant.arguments) > 0 {
                arguments_for_call := make([dynamic]^Op_Code)

                for index in 0..<len(variant.arguments) {
                    v := stack_pop(checker, stack, op.token)
                    inject_at(&arguments_for_call, 0, v)
                }

                proc_call.arguments = arguments_for_call[:]
            }

            if len(variant.results) > 0 {
                results_from_call := make([dynamic]^Op_Code)

                for type in variant.results {
                    new_result := new(Op_Code)
                    new_result.token = op.token
                    new_result.type = type
                    new_result.register = nil
                    new_result.variant = Op_Type_Lit{}
                    stack_push(checker, stack, new_result)
                    append(&results_from_call, new_result)
                }

                proc_call.results = results_from_call[:]
            }

            op.variant = proc_call

        case Entity_Procedure:
            proc_decl := entity.op_code.variant.(Op_Proc_Decl)
            proc_call := Op_Proc_Call{}
            proc_call.cname = proc_decl.cname
            proc_call.entity = entity

            if len(proc_decl.arguments) > 0 {
                arguments_for_call := make([dynamic]^Op_Code)
                temp_params_array := make([dynamic]^Type, context.temp_allocator)

                for arg in proc_decl.arguments {
                    append(&temp_params_array, arg.type)
                }

                if _stack_checks_failed(checker, op.token, stack, temp_params_array[:]) {
                    return
                }

                delete(temp_params_array)

                for index in 0..<len(proc_decl.arguments) {
                    v := stack_pop(checker, stack, op.token)
                    inject_at(&arguments_for_call, 0, v)
                }

                proc_call.arguments = arguments_for_call[:]
            }

            if len(proc_decl.results) > 0 {
                results_from_call := make([dynamic]^Op_Code)

                for result in proc_decl.results {
                    new_result := new_clone(result^)
                    new_result.register = nil
                    stack_push(checker, stack, new_result)
                    append(&results_from_call, new_result)
                }

                proc_call.results = results_from_call[:]
            }

            op.variant = proc_call
        }
    } else {
        // TODO(nawe) handle multiple
        assert(false)
    }
}

check_proc_decl :: proc(checker: ^Checker, op: ^Op_Code) {
    proc_op := op.variant.(Op_Proc_Decl)

    push_proc(checker, proc_op.scope)
    for arg in proc_op.arguments {
        stack_push(checker, checker.scope.stack, arg)
    }

    for child in proc_op.body {
        if checker.error_reported do break
        check_op(checker, child)
    }
    // do stack ops
    pop_proc(checker)
}

check_return :: proc(checker: ^Checker, op: ^Op_Code) {
    return_op := op.variant.(Op_Return)
    stack := checker.scope.stack

    if len(return_op.results) != len(stack.values) {
        checker_error(
            checker, op.token,
            "Mismatched number of results in procedure. Expected {} but got {}",
            len(return_op.results), len(stack.values),
        )
        return
    }

    for index in 0..<len(stack.values) {
        stack_value := stack.values[index]
        result_value := return_op.results[index]

        if !types_are_equal(stack_value.type, result_value.type) {
            checker_error(
                checker, op.token,
                "Mismatched type of results in procedure. Expected '{}' but got '{}'",
                type_to_string(stack_value.type), type_to_string(result_value.type),
            )
            return
        }

        // set the register to the stack value register so we can return
        result_value.register = stack_value.register
    }
}
