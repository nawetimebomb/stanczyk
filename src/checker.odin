package main

import "core:fmt"
import "core:slice"
import "core:strings"

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

get_current_stack :: proc() -> ^Stack {
    return compiler.current_scope.stack
}

pop_stack :: proc(ins: ^Instruction) -> ^Register {
    result, ok := pop_safe(get_current_stack())

    if !ok {
        checker_error(ins.token, STACK_EMPTY)
        checker_fatal_error()
    }

    return result
}

push_stack :: proc(r: ^Register) {
    append(get_current_stack(), r)
}

stack_is_valid_for_return :: proc(ins: ^Instruction) -> bool {
    procedure := compiler.current_proc
    stack := get_current_stack()

    if len(stack) != len(procedure.results) {
        checker_error(
            ins.token, MISMATCHED_NUMBER_RESULTS,
            len(procedure.results), procedure.name, len(stack),
        )
        return false
    }

    for index in 0..<len(procedure.results) {
        rt := procedure.results[index].type
        st := stack[index].type

        if st != rt {
            checker_error(
                ins.token, MISMATCHED_TYPES_RESULT,
                procedure.name, rt.name, st.name,
            )
            return false
        }
    }

    return true
}

can_this_proc_be_called :: proc(token: Token, procedure: ^Procedure, report_error := true) -> bool {
    stack_copy := slice.clone_to_dynamic(get_current_stack()[:], context.temp_allocator)

    if len(stack_copy) < len(procedure.arguments) {
        if report_error {
            checker_error(
                token, MISMATCHED_NUMBER_ARGS,
                procedure.name, len(procedure.arguments), len(stack_copy),
            )
        }
        return false
    }

    for index := len(procedure.arguments)-1; index >= 0; index -= 1 {
        arg := procedure.arguments[index]
        stack_value := pop(&stack_copy)

        // TODO(nawe) better check for this
        if arg.type != stack_value.type {
            if report_error {
                checker_error(
                    token, MISMATCHED_TYPES_ARG,
                    procedure.name, arg.type.name, stack_value.type.name,
                )
            }
            return false
        }
    }

    return true
}



check_program_bytecode :: proc() {
    assert(compiler.current_proc == compiler.global_proc)

    for instruction in compiler.global_proc.code {
        if compiler.error_reported {
            break
        }
        check_instruction(compiler.global_proc, instruction)
    }

    for procedure in bytecode {
        compiler.error_reported = false
        check_procedure(procedure)
    }

    if len(compiler.errors) > 0 {
        checker_fatal_error()
    }
}

check_procedure :: proc(procedure: ^Procedure) {
    _type_parameters :: proc(params: ^[]Parameter) {
        for &p in params {
            if p.type == nil {
                p.type = compiler.types[p.type_token.text]

                if p.type == nil {
                    checker_error(p.type_token, FAILED_TO_PARSE_TYPE)
                    checker_fatal_error()
                }
            }
        }
    }

    // make sure parameters and results are typed
    _type_parameters(&procedure.arguments)
    _type_parameters(&procedure.results)

    push_procedure(procedure)
    for instruction in procedure.code {
        if compiler.error_reported {
            break
        }
        check_instruction(procedure, instruction)
    }
    pop_procedure()
}

check_instruction :: proc(this_proc: ^Procedure, ins: ^Instruction) {
    stack := get_current_stack()

    switch &v in ins.variant {
    case BINARY_ADD:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        v.rhs = pop_stack(ins)
        v.lhs = pop_stack(ins)

        if v.lhs.type != v.rhs.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, v.lhs.type.name, v.rhs.type.name)
            return
        }

        push_stack(REGISTER(v.lhs.type, ins))

    case BINARY_MINUS:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        v.rhs = pop_stack(ins)
        v.lhs = pop_stack(ins)

        if v.lhs.type != v.rhs.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, v.lhs.type.name, v.rhs.type.name)
            return
        }

        push_stack(REGISTER(v.lhs.type, ins))

    case BINARY_MULTIPLY:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        v.rhs = pop_stack(ins)
        v.lhs = pop_stack(ins)

        if v.lhs.type != v.rhs.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, v.lhs.type.name, v.rhs.type.name)
            return
        }

        push_stack(REGISTER(v.lhs.type, ins))

    case BINARY_MODULO:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        v.rhs = pop_stack(ins)
        v.lhs = pop_stack(ins)

        if v.lhs.type != v.rhs.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, v.lhs.type.name, v.rhs.type.name)
            return
        }

        if v.lhs.type != type_int || v.rhs.type != type_int {
            checker_error(ins.token, MODULO_ONLY_INT, v.lhs.type.name)
            return
        }

        push_stack(REGISTER(v.lhs.type, ins))

    case BINARY_SLASH:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        v.rhs = pop_stack(ins)
        v.lhs = pop_stack(ins)

        if v.lhs.type != v.rhs.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, v.lhs.type.name, v.rhs.type.name)
            return
        }

        push_stack(REGISTER(v.lhs.type, ins))

    case CAST:
        unimplemented()

    case COMPARE_EQUAL:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        v.rhs = pop_stack(ins)
        v.lhs = pop_stack(ins)

        if v.lhs.type != v.rhs.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, v.lhs.type.name, v.rhs.type.name)
            return
        }

        push_stack(REGISTER(type_bool, ins))

    case COMPARE_NOT_EQUAL:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        v.rhs = pop_stack(ins)
        v.lhs = pop_stack(ins)

        if v.lhs.type != v.rhs.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, v.lhs.type.name, v.rhs.type.name)
            return
        }

        push_stack(REGISTER(type_bool, ins))

    case COMPARE_GREATER:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        v.rhs = pop_stack(ins)
        v.lhs = pop_stack(ins)

        if v.lhs.type != v.rhs.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, v.lhs.type.name, v.rhs.type.name)
            return
        }

        if !type_one_of(v.lhs.type, type_is_number, type_is_byte) {
            checker_error(
                ins.token, MISMATCHED_MULTI,
                ">", "float, int, uint, byte", v.lhs.type.name,
            )
            return
        }

        push_stack(REGISTER(type_bool, ins))

    case COMPARE_GREATER_EQUAL:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        v.rhs = pop_stack(ins)
        v.lhs = pop_stack(ins)

        if v.lhs.type != v.rhs.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, v.lhs.type.name, v.rhs.type.name)
            return
        }

        if !type_one_of(v.lhs.type, type_is_number, type_is_byte) {
            checker_error(
                ins.token, MISMATCHED_MULTI,
                ">=", "float, int, uint, byte", v.lhs.type.name,
            )
            return
        }

        push_stack(REGISTER(type_bool, ins))

    case COMPARE_LESS:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        v.rhs = pop_stack(ins)
        v.lhs = pop_stack(ins)

        if v.lhs.type != v.rhs.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, v.lhs.type.name, v.rhs.type.name)
            return
        }

        if !type_one_of(v.lhs.type, type_is_number, type_is_byte) {
            checker_error(
                ins.token, MISMATCHED_MULTI,
                "<", "float, int, uint, byte", v.lhs.type.name,
            )
            return
        }

        push_stack(REGISTER(type_bool, ins))

    case COMPARE_LESS_EQUAL:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        v.rhs = pop_stack(ins)
        v.lhs = pop_stack(ins)

        if v.lhs.type != v.rhs.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, v.lhs.type.name, v.rhs.type.name)
            return
        }

        if !type_one_of(v.lhs.type, type_is_number, type_is_byte) {
            checker_error(
                ins.token, MISMATCHED_MULTI,
                "<=", "float, int, uint, byte", v.lhs.type.name,
            )
            return
        }

        push_stack(REGISTER(type_bool, ins))

    case DECLARE_VAR_END:
        if len(stack) != 1 {
            checker_error(ins.token, VAR_DECL_MULTI_VALUE, len(stack))
            return
        }

        o1 := pop_stack(ins)
        o1.mutable = true
        pop_scope()
        create_entity(v.token, Entity_Var{o1})

    case DECLARE_VAR_START:
        var_decl_scope := create_scope(.Var_Decl)
        push_scope(var_decl_scope)

    case DROP:
        pop_stack(ins)

    case DUP:
        if len(stack) == 0 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 1, 0)
            return
        }
        o1 := pop_stack(ins)
        push_stack(o1)
        push_stack(o1)

    case DUP_PREV:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }
        o2 := pop_stack(ins)
        o1 := pop_stack(ins)
        push_stack(o1)
        push_stack(o1)
        push_stack(o2)

    case IDENTIFIER:
        matches := find_entity(v.value)

        if len(matches) == 0 {
            checker_error(ins.token, UNDEFINED_IDENTIFIER, v.value)
            return
        } else if len(matches) == 1 {
            entity := matches[0]

            switch variant in entity.variant {
            case Entity_Binding:
                ins.variant = PUSH_BIND{variant.value}

            case Entity_Const:
                ins.variant = PUSH_CONST{variant}

            case Entity_Proc:
                ins.variant = INVOKE_PROC{procedure = variant.procedure}

            case Entity_Type:
                ins.variant = PUSH_TYPE{variant.type}

            case Entity_Var:
                push_stack(variant.value)
                return
            }
        } else {
            // NOTE(nawe) these are always procedures, so we just need to know
            // if we can call them with the current stack status
            found := false

            for entity in matches {
                variant := entity.variant.(Entity_Proc)

                if can_this_proc_be_called(ins.token, variant.procedure, report_error = false) {
                    ins.variant = INVOKE_PROC{procedure = variant.procedure}
                    found = true
                }
            }

            if !found {
                checker_error(ins.token, NO_MATCHING_POLY_PROC)
                return
            }
        }

        // Re-check this instruction after it changed meanings
        check_instruction(this_proc, ins)

    case IF_ELSE_JUMP:
        if_scope := pop_scope()
        scope_opener_ins := this_proc.code[if_scope.update_offset]

        #partial switch &variant in scope_opener_ins.variant {
        case IF_FALSE_JUMP:
            variant.jump_offset = ins.offset
        case:
            assert(false, "Compiler Bug. Parser should have made sure that this case doesn't occur.")
        }

        push_scope(v.local_scope)
        clear(compiler.current_scope.parent.stack)
        for v in if_scope.stack {
            append(compiler.current_scope.parent.stack, v)
        }

    case IF_END:
        // This is a pretty complex section so it's worth some documentation, maybe at some
        // point I would like to work on @Robustness for the whole thing here.
        if_scope := pop_scope()
        scope_opener_ins := this_proc.code[if_scope.update_offset]

        #partial switch &variant in scope_opener_ins.variant {
        case IF_FALSE_JUMP:
            variant.jump_offset = ins.offset
        case IF_ELSE_JUMP:
            variant.jump_offset = ins.offset
        case:
            assert(false, "Compiler Bug. Parser should have made sure that this case doesn't occur.")
        }

        current_stack := compiler.current_scope.stack

        // We need to make sure the registers are aligned after exiting both if and
        // else statements. That means, we need to make sure the registers used are
        // the same ones, so, if we notice that the value doesn't match the one from
        // the stack in the conditional scope, we replace it and clean up the space used.
        #partial switch if_scope.kind {
        case .If:
            if !are_stacks_equals(ins.token, current_stack, if_scope.stack, "if") {
                return
            }

            for &v, i in if_scope.stack {
                if v != current_stack[i] {
                    index := v.index
                    compiler.current_proc.registers[index] = nil
                    v.index = current_stack[i].index
                }
            }

        case .If_Else:
            if !are_stacks_equals(ins.token, current_stack, if_scope.stack, "else") {
                return
            }

            for &v, i in if_scope.stack {
                if v != current_stack[i] {
                    index := v.index
                    compiler.current_proc.registers[index] = nil
                    v.index = current_stack[i].index
                }
            }

        case:
            assert(false, "Compiler Bug. Parser should have made sure that this case doesn't occur.")
        }

    case IF_FALSE_JUMP:
        if len(stack) == 0 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 1, 0)
            return
        }

        v.test_value = pop_stack(ins)

        if !type_is_boolean(v.test_value.type) {
            checker_error(ins.token, MISMATCHED_MULTI, "'bool'", v.test_value.type.name)
            return
        }

        push_scope(v.local_scope)

    case INVOKE_PROC:
        if !can_this_proc_be_called(ins.token, v.procedure) {
            return
        }

        v.arguments = make([]^Register, len(v.procedure.arguments))
        v.results   = make([]^Register, len(v.procedure.results))

        for index := len(v.procedure.arguments)-1; index >= 0; index -= 1 {
            arg := v.procedure.arguments[index]
            v.arguments[index] = pop_stack(ins)
        }

        for index in 0..<len(v.procedure.results) {
            v.results[index] = REGISTER(v.procedure.results[index].type)
            push_stack(v.results[index])
        }

    case NIP:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 1, 0)
            return
        }
        o2 := pop_stack(ins)
        o1 := pop_stack(ins)
        push_stack(o2)

    case OVER:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        o2 := pop_stack(ins)
        o1 := pop_stack(ins)
        push_stack(o1)
        push_stack(o2)
        push_stack(o1)

    case PRINT:
        if len(stack) == 0 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 1, 0)
            return
        }
        v.param = pop_stack(ins)

    case PUSH_ARG:
        push_stack(REGISTER(this_proc.arguments[v.value].type, ins))

    case PUSH_BIND:
        push_stack(v.value)

    case PUSH_BOOL:
        push_stack(REGISTER(type_bool, ins))

    case PUSH_BYTE:
        push_stack(REGISTER(type_byte, ins))

    case PUSH_CONST:
        push_stack(REGISTER(v.const.type, ins))

    case PUSH_FLOAT:
        push_stack(REGISTER(type_float, ins))

    case PUSH_INT:
        push_stack(REGISTER(type_int, ins))

    case PUSH_STRING:
        push_stack(REGISTER(type_string, ins))

    case PUSH_TYPE:
        unimplemented()

    case PUSH_UINT:
        push_stack(REGISTER(type_uint, ins))

    case RETURN:
        stack_is_valid_for_return(ins)

    case RETURN_VALUE:
        if stack_is_valid_for_return(ins) {
            v.value = stack[0]
        }

    case RETURN_VALUES:
        if stack_is_valid_for_return(ins) {
            for n in 0..<len(this_proc.results) {
                v.value[n] = stack[n]
            }
        }

    case ROTATE_LEFT:
        if len(stack) < 3 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 3, len(stack))
            return
        }

        o3 := pop_stack(ins)
        o2 := pop_stack(ins)
        o1 := pop_stack(ins)
        push_stack(o2)
        push_stack(o3)
        push_stack(o1)

    case ROTATE_RIGHT:
        if len(stack) < 3 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 3, len(stack))
            return
        }

        o3 := pop_stack(ins)
        o2 := pop_stack(ins)
        o1 := pop_stack(ins)
        push_stack(o3)
        push_stack(o1)
        push_stack(o2)

    case STORE_BIND:
        if len(stack) == 0 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 1, 0)
            return
        }

        create_entity(v.token, Entity_Binding{value = pop_stack(ins)})

    case STORE_VAR:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        o2 := pop_stack(ins)
        o1 := pop_stack(ins)

        if o1.type != o2.type {
            checker_error(ins.token, MISMATCHED_TYPES_IN_VAR, o1.type.name, o2.type.name)
            return
        }

        if !o2.mutable {
            checker_error(ins.token, NOT_A_MUTABLE_VAR)
            return
        }

        v.lvalue = o2
        v.rvalue = o1

    case SWAP:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        o2 := pop_stack(ins)
        o1 := pop_stack(ins)
        push_stack(o2)
        push_stack(o1)

    case TUCK:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        o2 := pop_stack(ins)
        o1 := pop_stack(ins)
        push_stack(o2)
        push_stack(o1)
        push_stack(o2)
    }
}
