package main

import "core:fmt"
import "core:strings"

Checker :: struct {
    stack:     [dynamic]^Register,
    procedure: ^Procedure,
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

pop_stack :: proc(ins: ^Instruction) -> ^Register {
    result, ok := pop_safe(&compiler.checker.stack)

    if !ok {
        checker_error(ins.token, STACK_EMPTY)
        checker_fatal_error()
    }

    return result
}

push_stack :: proc(r: ^Register) {
    append(&compiler.checker.stack, r)
}

stack_is_valid_for_return :: proc(ins: ^Instruction) -> bool {
    procedure := compiler.checker.procedure
    stack := compiler.checker.stack

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

init_checker :: proc() {
    compiler.checker = new(Checker)
    compiler.checker.stack = make([dynamic]^Register, 0, 8)
    compiler.checker.procedure = compiler.curr_proc
}

destroy_checker :: proc() {
    delete(compiler.checker.stack)
    free(compiler.checker)
    compiler.checker = nil
}



check_program_bytecode :: proc() {
    assert(compiler.current_scope == compiler.global_scope)

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
    init_checker()
    for instruction in procedure.code {
        if compiler.error_reported {
            break
        }
        check_instruction(procedure, instruction)
    }
    destroy_checker()
    pop_procedure()
}

check_instruction :: proc(this_proc: ^Procedure, ins: ^Instruction) {
    stack := compiler.checker.stack

    switch &v in ins.variant {
    case BINARY_ADD:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        o2 := pop_stack(ins)
        o1 := pop_stack(ins)

        if o1.type != o2.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, o1.type.name, o2.type.name)
            return
        }

        v.lhs = o1.index
        v.rhs = o2.index
        push_stack(REGISTER(o1.type, ins))

    case BINARY_MINUS:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        o2 := pop_stack(ins)
        o1 := pop_stack(ins)

        if o1.type != o2.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, o1.type.name, o2.type.name)
            return
        }

        v.lhs = o1.index
        v.rhs = o2.index
        push_stack(REGISTER(o1.type, ins))

    case BINARY_MULTIPLY:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        o2 := pop_stack(ins)
        o1 := pop_stack(ins)

        if o1.type != o2.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, o1.type.name, o2.type.name)
            return
        }

        v.lhs = o1.index
        v.rhs = o2.index
        push_stack(REGISTER(o1.type, ins))

    case BINARY_MODULO:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        o2 := pop_stack(ins)
        o1 := pop_stack(ins)

        if o1.type != o2.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, o1.type.name, o2.type.name)
            return
        }

        if o1.type != type_int || o2.type != type_int {
            checker_error(ins.token, MODULO_ONLY_INT, o1.type.name)
            return
        }

        v.lhs = o1.index
        v.rhs = o2.index
        push_stack(REGISTER(o1.type, ins))

    case BINARY_SLASH:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        o2 := pop_stack(ins)
        o1 := pop_stack(ins)

        if o1.type != o2.type {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, o1.type.name, o2.type.name)
            return
        }

        v.lhs = o1.index
        v.rhs = o2.index
        push_stack(REGISTER(o1.type, ins))

    case CAST:
        unimplemented()

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

    case IDENTIFIER:
        matches := find_entity(v.value)

        if len(matches) == 0 {
            checker_error(ins.token, UNDEFINED_IDENTIFIER, v.value)
            return
        } else if len(matches) == 1 {
            entity := matches[0]

            switch variant in entity.variant {
            case Entity_Const:

            case Entity_Proc:
                ins.variant = INVOKE_PROC{
                    procedure = variant.procedure,
                }
            case Entity_Type:
                ins.variant = PUSH_TYPE{variant.type}
            }
        } else {
            unimplemented("polymorphism")
        }

        // Re-check this instruction after it changed meanings
        check_instruction(this_proc, ins)

    case INVOKE_PROC:
        if len(stack) < len(v.procedure.arguments) {
            checker_error(
                ins.token, MISMATCHED_NUMBER_ARGS,
                v.procedure.name, len(v.procedure.arguments), len(stack),
            )
            return
        }

        v.arguments = make([]^Register, len(v.procedure.arguments))
        v.results   = make([]^Register, len(v.procedure.results))

        for index := len(v.procedure.arguments)-1; index >= 0; index -= 1 {
            arg := v.procedure.arguments[index]
            stack_value := pop_stack(ins)

            if arg.type != stack_value.type {
                checker_error(
                    ins.token, MISMATCHED_TYPES_ARG,
                    v.procedure.name, arg.type.name, stack_value.type.name,
                )
                return
            }

            v.arguments[index] = stack_value
        }

        for index in 0..<len(v.procedure.results) {
            v.results[index] = REGISTER(v.procedure.results[index].type)
            push_stack(v.results[index])
        }

    case PRINT:
        if len(stack) == 0 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 1, 0)
            return
        }
        v.param = pop_stack(ins)

    case PUSH_ARG:
        push_stack(REGISTER(this_proc.arguments[v.value].type, ins))

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
    }
}
