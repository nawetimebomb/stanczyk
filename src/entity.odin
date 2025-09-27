package main

import "core:fmt"
import "core:reflect"
import "core:slice"

Stack :: distinct [dynamic]^Type

Entity :: struct {
    is_global: bool,
    name:      string,
    token:     Token,
    variant:   Entity_Variant,
}

Entity_Variant :: union {
    Entity_Binding,
    Entity_Const,
    Entity_Proc,
    Entity_Type,
    Entity_Var,
}

Entity_Binding :: struct {
    offset: int,
    type:   ^Type,
}

Entity_Const :: struct {
    index: int,
    type:  ^Type,
    value: Constant_Value,
}

Entity_Proc :: struct {
    procedure: ^Procedure,
}

Entity_Type :: struct {
    type: ^Type,
}

Entity_Var :: struct {
    offset: int,
    type:   ^Type,
}

Scope :: struct {
    entities:         [dynamic]^Entity,
    parent:           ^Scope,
    kind:             Scope_Kind,
    scope_id:         int,
    stack_snapshots:  [dynamic]^Stack,
}

Scope_Kind :: enum u8 {
    Global,
    Procedure,
    Branch_Then,
    Branch_Else,
    For_Loop,
}

Scope_Validation :: enum {
    None,
    Stack_Unchanged,
    Stacks_Match,
}

register_global_const_entities :: proc() {
    create_entity(
        make_token("OS_DARWIN"),
        Entity_Const{
            type  = type_bool,
            value = ODIN_OS == .Darwin,
        },
    )

    create_entity(
        make_token("OS_LINUX"),
        Entity_Const{
            type  = type_bool,
            value = ODIN_OS == .Linux,
        },
    )

    create_entity(
        make_token("OS_WINDOWS"),
        Entity_Const{
            type  = type_bool,
            value = ODIN_OS == .Windows,
        },
    )

    create_entity(
        make_token("OS_NAME"),
        Entity_Const{
            index = add_to_constants(reflect.enum_string(ODIN_OS)),
            type  = type_string,
            value = reflect.enum_string(ODIN_OS),
        },
    )

    create_entity(
        make_token("SK_DEBUG"),
        Entity_Const{
            type  = type_bool,
            value = switch_debug,
        },
    )
}

create_entity :: proc(token: Token, variant: Entity_Variant) -> ^Entity {
    entity := new(Entity)
    entity.is_global = is_in_global_scope()
    entity.name      = token.text
    entity.token     = token
    entity.variant   = variant

    found: ^Entity

    for ent in compiler.current_scope.entities {
        if ent.name == entity.name {
            found = ent
            break
        }
    }

    if token.text == "main" && compiler.main_found_at != nil {
        main_token := compiler.main_found_at
        fullpath := main_token.file_info.fullpath
        line := main_token.l0
        column := main_token.c0
        checker_error(token, REDECLARATION_OF_MAIN, fullpath, line, column)
        checker_fatal_error()
    }

    if found != nil {
        _, found_ok := found.variant.(Entity_Proc)
        _, curr_ok := entity.variant.(Entity_Proc)

        if !found_ok || !curr_ok {
            checker_error(token, REDECLARATION_FOUND, token.text)
        }
    }

    append(&compiler.current_scope.entities, entity)
    return entity
}

find_entity :: proc(name: string) -> []^Entity {
    results := make([dynamic]^Entity, context.temp_allocator)
    scope := compiler.current_scope

    for scope != nil {
        for ent in scope.entities {
            if ent.name == name {
                append(&results, ent)
            }
        }

        if len(results) > 0 {
            break
        }

        scope = scope.parent
    }

    return results[:]
}

create_scope :: proc(kind: Scope_Kind) -> ^Scope {
    new_scope := new(Scope)
    new_scope.kind = kind

    return new_scope
}

push_scope :: proc(new_scope: ^Scope) {
    assert(new_scope != nil)

    new_scope.parent = compiler.current_scope
    compiler.current_scope = new_scope
}

pop_scope :: proc(token: Token, validation: Scope_Validation = .None) -> ^Scope {
    _stacks_invalid :: proc(token: Token, a, b: ^Stack) -> bool {
        if len(a) != len(b) {
            checker_error(token, STACK_SIZE_CHANGED, len(a), len(b))
            return true
        }

        for i in 0..<len(a) {
            if a[i] != b[i] {
                checker_error(
                    token, STACK_COMP_CHANGED, i + 1,
                    a[i].name, b[i].name,
                )
                return true
            }
        }

        return false
    }

    old_scope := compiler.current_scope
    compiler.current_scope = old_scope.parent
    this_proc := compiler.current_proc

    switch validation {
    case .None:
    case .Stack_Unchanged:
        stack_copies := &old_scope.stack_snapshots
        assert(len(stack_copies) > 0)

        for index := 0; index < len(stack_copies)-1; index += 1 {
            a := stack_copies[index]
            b := stack_copies[index+1]
            if _stacks_invalid(token, a, b) {
                break
            }
        }
    case .Stacks_Match:
        stack_copies := &old_scope.stack_snapshots
        assert(len(stack_copies) > 1)

        for index := 1; index < len(stack_copies)-1; index += 1 {
            a := stack_copies[index]
            b := stack_copies[index+1]
            if _stacks_invalid(token, a, b) {
                break
            }
        }
    }

    return old_scope
}

push_procedure :: proc(procedure: ^Procedure) {
    procedure.parent = compiler.current_proc
    compiler.current_proc = procedure
    push_scope(procedure.scope)
}

pop_procedure :: proc() {
    token := compiler.current_proc.token
    compiler.current_proc = compiler.current_proc.parent
    pop_scope(token)
}
