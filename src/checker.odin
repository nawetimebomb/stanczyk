package main

import "core:fmt"
import "core:strings"

CHECKER_MISMATCHED_TYPE_PROC_ARGS :: "Mismatched types in procedure arguments. Expected {}, got {}."
CHECKER_MISMATCHED_TYPE :: "Binary operation between different types is not allowed {} vs {}."
CHECKER_MISSING_IDENTIFIER_DECLARATION :: "We could not find the meaning of identifier '{}'."
CHECKER_NOT_ENOUGH_VALUES_IN_STACK :: "Not enough stack values to make this operation."
CHECKER_NOT_A_NUMBER :: "We could not parse number."
CHECKER_TYPES_NOT_ALLOWED_IN_OPERATION :: "The types of elements in the stack can not be used in the following operation ({} {} {})."

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
    Entity_Procedure,
    Entity_Type,
}

Entity_Procedure :: struct {}

Entity_Type :: struct {
    type: ^Type,
}

checker_error :: proc(token: Token, format: string, args: ..any) {
    compiler.error_reported = true
    message := fmt.aprintf(format, ..args)
    append(&compiler.errors, Compiler_Error{
        message = message,
        token   = token,
    })
}

checker_fatal_error :: proc() {
    report_all_errors()
    errors_count := len(compiler.errors)
    fatalf(
        .Checker, "found {} {} while doing type checking.",
        errors_count, errors_count > 1 ? "errors" : "error",
    )
}

stack_reset :: proc(stack: ^Stack) {
    clear(&stack.values)
}

stack_push :: proc(stack: ^Stack, op: ^Op_Code) {
    if op.register == nil {
        op.register = add_register(op.type)
    }

    append(&stack.values, op)
}

stack_pop :: proc(stack: ^Stack, token: Token) -> ^Op_Code {
    value, ok := pop_safe(&stack.values)

    if !ok {
        checker_error(token, CHECKER_NOT_ENOUGH_VALUES_IN_STACK)
        checker_fatal_error()
    }

    return value
}

add_register :: proc(type: ^Type, prefix := REGISTER_PREFIX) -> ^Register {
    assert(compiler.proc_scope != nil)
    proc_op := &compiler.proc_scope.op_code.variant.(Op_Proc_Decl)
    IP := 0

    if _, exists := proc_op.registers[type]; exists {
        IP = len(proc_op.registers[type])
    } else {
        proc_op.registers[type] = make([dynamic]Register)
    }

    append(&proc_op.registers[type], Register{prefix=prefix, ip=IP, type=type})
    return &proc_op.registers[type][IP]
}

create_entity :: proc(name: string, op: ^Op_Code, variant: Entity_Variant) -> ^Entity {
    entity := new(Entity)
    entity.op_code = op
    entity.name    = name
    entity.variant = variant

    append(&compiler.current_scope.entities, entity)
    return entity
}

find_entity :: proc(name: string, deep_search := true) -> []^Entity {
    result := make([dynamic]^Entity, context.temp_allocator)
    scope := compiler.current_scope

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
    //for op in program_bytecode {
    //    check_create_entities(op)
    //}

    assert(compiler.current_scope == compiler.global_scope)

    for op in program_bytecode {
        compiler.error_reported = false
        check_op(op)
    }

    if len(compiler.errors) > 0 {
        checker_fatal_error()
    }
}

check_op :: proc(op: ^Op_Code) {
    switch &variant in op.variant {
    case Op_Identifier:
        check_identifier(op)

    case Op_Constant:
        stack_push(compiler.current_scope.stack, op)
    case Op_Proc_Call:
        check_op_proc_call(op)
        // maybe not needed?
    case Op_Plus:
        v2 := stack_pop(compiler.current_scope.stack, op.token)
        v1 := stack_pop(compiler.current_scope.stack, op.token)
        op.type = v1.type

        variant.lhs = v1.register
        variant.rhs = v2.register
        stack_push(compiler.current_scope.stack, op)

    case Op_Return:
        check_return(op)

    case Op_Proc_Decl:
        check_op_proc_decl(op)

    case Op_Type_Lit:

    case Op_Binary_Expr:
        check_binary_expr(op)

    case Op_Drop:
        stack_pop(compiler.current_scope.stack, op.token)
    }
}

check_binary_expr :: proc(op: ^Op_Code) {
    binary_op := &op.variant.(Op_Binary_Expr)
    v2 := stack_pop(compiler.current_scope.stack, op.token)
    v1 := stack_pop(compiler.current_scope.stack, op.token)

    op.type = v1.type
    binary_op.lhs = v1.register
    binary_op.rhs = v2.register

    stack_push(compiler.current_scope.stack, op)
}

check_identifier :: proc(op: ^Op_Code) {
    name := op.variant.(Op_Identifier).value.text
    matches := find_entity(name, true)

    if len(matches) == 0 {
        checker_error(
            op.token,
            CHECKER_MISSING_IDENTIFIER_DECLARATION, name,
        )
        return
    } else if len(matches) == 1 {
        entity := matches[0]
        stack := compiler.current_scope.stack

        switch variant in entity.variant {
        case Entity_Procedure:
            proc_decl := entity.op_code.variant.(Op_Proc_Decl)
            op.variant = Op_Proc_Call{
                foreign_name = proc_decl.foreign_name,
                entity = entity,
            }
            check_op_proc_call(op)
        case Entity_Type: assert(false)
        }
    } else {
        // TODO(nawe) handle multiple
        assert(false)
    }
}

check_op_proc_call :: proc(op: ^Op_Code) {
    _stack_checks_failed :: proc(token: Token, stack: ^Stack, params: []^Op_Code) -> bool {
        if len(stack.values) < len(params) {
            checker_error(token, CHECKER_NOT_ENOUGH_VALUES_IN_STACK)
            return true
        }
        stack_needed := stack.values[len(stack.values) - len(params):]

        for index in 0..<len(stack_needed) {
            stack_value := stack_needed[index]
            arg_value := params[index]

            if !types_are_equal(stack_value.type, arg_value.type) {
                checker_error(
                    token, CHECKER_MISMATCHED_TYPE_PROC_ARGS,
                    type_to_string(arg_value.type), type_to_string(stack_value.type),
                )
                return true
            }
        }

        return false
    }

    proc_call := &op.variant.(Op_Proc_Call)
    stack := compiler.current_scope.stack

    #partial switch variant in proc_call.entity.variant {
    case Entity_Procedure:
        proc_decl := proc_call.entity.op_code.variant.(Op_Proc_Decl)

        if len(proc_decl.arguments) > 0 {
            arguments_for_call := make([dynamic]^Op_Code)

            if _stack_checks_failed(op.token, stack, proc_decl.arguments) {
                return
            }

            for index in 0..<len(proc_decl.arguments) {
                v := stack_pop(stack, op.token)
                inject_at(&arguments_for_call, 0, v)
            }

            proc_call.arguments = arguments_for_call[:]
        }

        if len(proc_decl.results) > 0 {
            results_from_call := make([dynamic]^Op_Code)

            for result in proc_decl.results {
                new_result := new_clone(result^)
                new_result.register = nil
                stack_push(stack, new_result)
                append(&results_from_call, new_result)
            }

            proc_call.results = results_from_call[:]
        }
    }
}

check_op_proc_decl :: proc(op: ^Op_Code) {
    proc_op := op.variant.(Op_Proc_Decl)

    push_proc(proc_op.scope)
    for arg in proc_op.arguments {
        stack_push(compiler.current_scope.stack, arg)
    }

    for child in proc_op.body {
        if compiler.error_reported do break
        check_op(child)
    }
    pop_proc()
}

check_return :: proc(op: ^Op_Code) {
    return_op := op.variant.(Op_Return)
    stack := compiler.current_scope.stack

    if len(return_op.results) != len(stack.values) {
        checker_error(
            op.token,
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
                op.token,
                "Mismatched type of results in procedure. Expected '{}' but got '{}'",
                type_to_string(stack_value.type), type_to_string(result_value.type),
            )
            return
        }

        // set the register to the stack value register so we can return
        result_value.register = stack_value.register
    }
}
