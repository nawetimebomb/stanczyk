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

get_last_snapshot :: proc() -> ^Stack {
    return compiler.current_scope.stack_snapshots[len(compiler.current_scope.stack_snapshots)-1]
}

get_current_stack :: proc() -> ^Stack {
    return compiler.current_proc.stack
}

pop_stack :: proc() -> ^Type {
    result := pop(get_current_stack())
    return result
}

push_stack :: proc(t: ^Type) {
    append(get_current_stack(), t)
}

snapshot_stack :: proc() {
    stack := get_current_stack()
    temp := new(Stack, context.temp_allocator)

    for v in stack {
        append(temp, v)
    }

    append(&compiler.current_scope.stack_snapshots, temp)
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
        st := stack[index]

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
        arg_type := procedure.arguments[index].type
        stack_value_type := pop(&stack_copy)

        if !types_equal(arg_type, stack_value_type) {
            if report_error {
                checker_error(
                    token, MISMATCHED_TYPES_ARG,
                    procedure.name, arg_type.name, stack_value_type.name,
                )
            }
            return false
        }
    }

    return true
}



check_program_bytecode :: proc() {
    assert(compiler.current_proc == compiler.global_proc)

    compiler.global_proc.stack = new(Stack, context.temp_allocator)
    for instruction in compiler.global_proc.code {
        if compiler.error_reported {
            break
        }
        check_instruction(compiler.global_proc, instruction)
    }

    for procedure in bytecode {
        check_procedure_arguments_results(procedure)
    }

    for procedure in bytecode {
        compiler.error_reported = false
        check_procedure(procedure)
    }

    if len(compiler.errors) > 0 {
        checker_fatal_error()
    }
}

check_procedure_arguments_results :: proc(procedure: ^Procedure) {
    _type_parameters :: proc(params: ^[]Parameter) {
        for &p in params {
            if p.type == nil {
                type: ^Type

                if p.quoted {
                    type = type_pointer_to(compiler.types_by_name[p.type_token.text])
                } else {
                    type = compiler.types_by_name[p.type_token.text]
                }

                p.type = type

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
}

check_procedure :: proc(procedure: ^Procedure) {
    push_procedure(procedure)
    procedure.stack = new(Stack, context.temp_allocator)

    for arg in procedure.arguments {
        push_stack(arg.type)
    }

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

        rhs := pop_stack()
        lhs := pop_stack()
        v.type = lhs

        if lhs != rhs {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, lhs.name, rhs.name)
            return
        }

        push_stack(v.type)

    case BINARY_DIVIDE:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        rhs := pop_stack()
        lhs := pop_stack()
        v.type = lhs

        if lhs != rhs {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, lhs.name, rhs.name)
            return
        }

        push_stack(v.type)

    case BINARY_MINUS:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        rhs := pop_stack()
        lhs := pop_stack()
        v.type = lhs

        if lhs != rhs {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, lhs.name, rhs.name)
            return
        }

        push_stack(v.type)

    case BINARY_MULTIPLY:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        rhs := pop_stack()
        lhs := pop_stack()
        v.type = lhs

        if lhs != rhs {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, lhs.name, rhs.name)
            return
        }

        push_stack(v.type)

    case BINARY_MODULO:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        rhs := pop_stack()
        lhs := pop_stack()
        v.type = lhs

        if lhs != rhs {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, lhs.name, rhs.name)
            return
        }

        // TODO(nawe) support other types of values at some point
        if lhs != type_int || rhs != type_int {
            checker_error(ins.token, MODULO_ONLY_INT, lhs.name)
            return
        }

        push_stack(v.type)

    case CAST:
        unimplemented()

    case COMPARE_EQUAL:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        rhs := pop_stack()
        lhs := pop_stack()
        v.type = lhs

        if lhs != rhs {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, lhs.name, rhs.name)
            return
        }

        push_stack(type_bool)

    case COMPARE_NOT_EQUAL:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        rhs := pop_stack()
        lhs := pop_stack()
        v.type = lhs

        if lhs != rhs {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, lhs.name, rhs.name)
            return
        }

        push_stack(type_bool)

    case COMPARE_GREATER:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        rhs := pop_stack()
        lhs := pop_stack()
        v.type = lhs

        if lhs != rhs {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, lhs.name, rhs.name)
            return
        }

        if !type_one_of(lhs, type_is_number, type_is_byte) {
            checker_error(
                ins.token, MISMATCHED_MULTI,
                ">", "float, int, uint, byte", lhs.name,
            )
            return
        }

        push_stack(type_bool)

    case COMPARE_GREATER_EQUAL:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        rhs := pop_stack()
        lhs := pop_stack()
        v.type = lhs

        if lhs != rhs {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, lhs.name, rhs.name)
            return
        }

        if !type_one_of(lhs, type_is_number, type_is_byte) {
            checker_error(
                ins.token, MISMATCHED_MULTI,
                ">=", "float, int, uint, byte", lhs.name,
            )
            return
        }

        push_stack(type_bool)

    case COMPARE_LESS:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        rhs := pop_stack()
        lhs := pop_stack()
        v.type = lhs

        if lhs != rhs {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, lhs.name, rhs.name)
            return
        }

        if !type_one_of(lhs, type_is_number, type_is_byte) {
            checker_error(
                ins.token, MISMATCHED_MULTI,
                "<", "float, int, uint, byte", lhs.name,
            )
            return
        }

        push_stack(type_bool)

    case COMPARE_LESS_EQUAL:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        rhs := pop_stack()
        lhs := pop_stack()
        v.type = lhs

        if lhs != rhs {
            checker_error(ins.token, MISMATCHED_TYPES_BINARY_EXPR, lhs.name, rhs.name)
            return
        }

        if !type_one_of(lhs, type_is_number, type_is_byte) {
            checker_error(
                ins.token, MISMATCHED_MULTI,
                "<=", "float, int, uint, byte", lhs.name,
            )
            return
        }

        push_stack(type_bool)

    case DROP:
        pop_stack()

    case DUP:
        if len(stack) == 0 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 1, 0)
            return
        }
        type := pop_stack()
        push_stack(type)
        push_stack(type)

    case DUP_PREV:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }
        type2 := pop_stack()
        type1 := pop_stack()
        push_stack(type1)
        push_stack(type1)
        push_stack(type2)

    case IDENTIFIER:
        matches := find_entity(v.value)

        if len(matches) == 0 {
            checker_error(ins.token, UNDEFINED_IDENTIFIER, v.value)
            return
        } else if len(matches) == 1 {
            entity := matches[0]

            switch variant in entity.variant {
            case Entity_Binding:
                ins.variant = PUSH_BIND{variant.offset, variant.type}

            case Entity_Const:
                ins.variant = PUSH_CONST{variant}

            case Entity_Proc:
                ins.variant = INVOKE_PROC{procedure=variant.procedure}

            case Entity_Type:
                ins.variant = PUSH_TYPE{variant.type}

            case Entity_Var:
                if entity.is_global {
                    ins.variant = PUSH_VAR_GLOBAL{variant.offset, variant.type}
                } else {
                    ins.variant = PUSH_VAR_LOCAL{variant.offset, variant.type}
                }
            }
        } else {
            // NOTE(nawe) these are always procedures, so we just need to know
            // if we can call them with the current stack status
            found := false

            for entity in matches {
                variant := entity.variant.(Entity_Proc)

                if can_this_proc_be_called(ins.token, variant.procedure, report_error = false) {
                    ins.variant = INVOKE_PROC{procedure=variant.procedure}
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
        last_snapshot := get_last_snapshot()
        snapshot_stack()
        clear(get_current_stack())
        for x in last_snapshot {
            push_stack(x)
        }

    case IF_END:
        scope := compiler.current_scope
        snapshot_stack()

        if scope.kind == .Branch_Then {
            pop_scope(ins.token, .Stack_Unchanged)
        } else {
            pop_scope(ins.token, .Stacks_Match)
        }

    case IF_FALSE_JUMP:
        if len(stack) == 0 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 1, 0)
            return
        }

        condition := pop_stack()

        if !type_is_boolean(condition) {
            checker_error(ins.token, IF_STATEMENT_NO_BOOLEAN, condition.name)
            return
        }

        push_scope(v.scope)
        snapshot_stack()

    case INVOKE_PROC:
        if !can_this_proc_be_called(ins.token, v.procedure) {
            return
        }

        v.arguments = make([]^Type, len(v.procedure.arguments))
        v.results   = make([]^Type, len(v.procedure.results))

        for index := len(v.procedure.arguments)-1; index >= 0; index -= 1 {
            arg := v.procedure.arguments[index]
            v.arguments[index] = pop_stack()
        }

        for index in 0..<len(v.procedure.results) {
            v.results[index] = v.procedure.results[index].type
            push_stack(v.results[index])
        }

    case LEN:
        if len(stack) == 0 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 1, 0)
            return
        }

        v.type = pop_stack()
        push_stack(type_int)

    case LOOP_BREAK:
        snapshot_stack()

    case LOOP_CONTINUE:
        snapshot_stack()

    case LOOP_END:
        snapshot_stack()
        pop_scope(ins.token, .Stack_Unchanged)

    case LOOP_ITERATE:
        DEFAULT_BINDS :: [3]string{"iteratee", "index", "it"}

        push_scope(v.scope)

        if len(stack) == 0 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 1, 0)
            return
        }

        type := pop_stack()
        bound_types: [3]^Type

        switch {
        case type_is_string(type):
            v.kind = .String
            bound_types = {type_string, type_int, type_byte}
        case:
            checker_error(ins.token, CANNOT_ITERATE_ON_TYPE, type.name)
            return
        }

        binds := DEFAULT_BINDS
        for token, index in v.tokens {
            binds[2-index] = token.text
        }

        for bind, index in binds {
            offset := this_proc.stack_frame_size
            token := ins.token
            token.text = bind
            create_entity(token, Entity_Binding{offset=offset, type=bound_types[index]})

            this_proc.stack_frame_size += type_int.size_in_bytes
            v.offsets[index] = offset
        }

        snapshot_stack()

    case LOOP_RANGE:
        push_scope(v.scope)

        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        type2 := pop_stack()
        type1 := pop_stack()

        if !type_is_integer(type1) || !type_is_integer(type2) {
            checker_error(ins.token, AUTORANGE_LOOP_MISMATCHED_TYPES, type1.name, type2.name)
            return
        }

        DEFAULT_BINDS :: [3]string{"limit", "index", "it"}
        binds := DEFAULT_BINDS
        for token, index in v.tokens {
            binds[2-index] = token.text
        }


        for bind, index in binds {
            offset := this_proc.stack_frame_size
            token := ins.token
            token.text = bind
            create_entity(token, Entity_Binding{offset=offset, type=type_int})

            this_proc.stack_frame_size += type_int.size_in_bytes
            v.offsets[index] = offset
        }

        snapshot_stack()

    case NIP:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 1, 0)
            return
        }

        type2 := pop_stack()
        type1 := pop_stack()
        push_stack(type2)

    case OVER:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        type2 := pop_stack()
        type1 := pop_stack()
        push_stack(type1)
        push_stack(type2)
        push_stack(type1)

    case PRINT:
        if len(stack) == 0 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 1, 0)
            return
        }
        v.type = pop_stack()

    case PUSH_BIND:
        push_stack(v.type)

    case PUSH_BOOL:
        push_stack(type_bool)

    case PUSH_BYTE:
        push_stack(type_byte)

    case PUSH_CONST:
        push_stack(v.const.type)

    case PUSH_FLOAT:
        push_stack(type_float)

    case PUSH_INT:
        push_stack(type_int)

    case PUSH_STRING:
        push_stack(type_string)

    case PUSH_TYPE:
        unimplemented()

    case PUSH_UINT:
        push_stack(type_uint)

    case PUSH_VAR_GLOBAL:
        if ins.quoted {
            push_stack(type_pointer_to(v.type))
        } else {
            push_stack(v.type)
        }

    case PUSH_VAR_LOCAL:
        if ins.quoted {
            push_stack(type_pointer_to(v.type))
        } else {
            push_stack(v.type)
        }

    case RETURN:
        stack_is_valid_for_return(ins)

    case RETURN_VALUE:
        stack_is_valid_for_return(ins)

    case RETURN_VALUES:
        stack_is_valid_for_return(ins)

    case ROTATE_LEFT:
        if len(stack) < 3 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 3, len(stack))
            return
        }

        type3 := pop_stack()
        type2 := pop_stack()
        type1 := pop_stack()
        push_stack(type2)
        push_stack(type3)
        push_stack(type1)

    case ROTATE_RIGHT:
        if len(stack) < 3 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 3, len(stack))
            return
        }

        type3 := pop_stack()
        type2 := pop_stack()
        type1 := pop_stack()
        push_stack(type3)
        push_stack(type1)
        push_stack(type2)

    case SET:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        ptr := pop_stack()
        value_t := pop_stack()

        if !type_is_pointer_of(ptr, value_t) {
            checker_error(ins.token, MISMATCHED_POINTER_TYPE, ptr.name, value_t.name)
            return
        }

    case STORE_BIND:
        if len(stack) == 0 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 1, 0)
            return
        }

        type := pop_stack()
        v.offset = this_proc.stack_frame_size
        create_entity(v.token, Entity_Binding{offset=v.offset, type=type})
        this_proc.stack_frame_size += type.size_in_bytes

    case STORE_VAR_GLOBAL:
        if len(stack) == 0 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 1, 0)
            return
        }

        type := pop_stack()
        v.offset = this_proc.stack_frame_size
        create_entity(v.token, Entity_Var{offset=this_proc.stack_frame_size, type=type})
        this_proc.stack_frame_size += type.size_in_bytes

    case STORE_VAR_LOCAL:
        if len(stack) == 0 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 1, 0)
            return
        }

        type := pop_stack()
        v.offset = this_proc.stack_frame_size
        create_entity(v.token, Entity_Var{offset=this_proc.stack_frame_size, type=type})
        this_proc.stack_frame_size += type.size_in_bytes

    case SWAP:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        type2 := pop_stack()
        type1 := pop_stack()
        push_stack(type2)
        push_stack(type1)

    case TUCK:
        if len(stack) < 2 {
            checker_error(ins.token, STACK_EMPTY_EXPECT, 2, len(stack))
            return
        }

        type2 := pop_stack()
        type1 := pop_stack()
        push_stack(type2)
        push_stack(type1)
        push_stack(type2)
    }
}
