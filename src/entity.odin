package main

import "core:fmt"
import "core:reflect"
import "core:slice"

Stack :: distinct [dynamic]^Type

Entity :: struct {
    name:    string,
    token:   Token,
    variant: Entity_Variant,
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
    entities:      [dynamic]^Entity,
    parent:        ^Scope,
    kind:          Scope_Kind,
    stack:         ^Stack,
    update_offset: int,
}

Scope_Kind :: enum u8 {
    Global,
    Procedure,
    Var_Decl,
    If,
    If_Else,
}

Constant_Value :: union {
    bool,
    f64,
    i64,
    string,
    u64,
    u8,
}

register_global_const_entities :: proc() {
    create_entity(
        make_token("OS_DARWIN"),
        Entity_Const{type_bool, ODIN_OS == .Darwin},
    )

    create_entity(
        make_token("OS_LINUX"),
        Entity_Const{type_bool, ODIN_OS == .Linux},
    )

    create_entity(
        make_token("OS_WINDOWS"),
        Entity_Const{type_bool, ODIN_OS == .Windows},
    )

    create_entity(
        make_token("OS_NAME"),
        Entity_Const{type_string, reflect.enum_string(ODIN_OS)},
    )

    create_entity(
        make_token("SK_DEBUG"),
        Entity_Const{type_bool, switch_debug},
    )
}

create_entity :: proc(token: Token, variant: Entity_Variant) -> ^Entity {
    entity := new(Entity)
    entity.name    = token.text
    entity.token   = token
    entity.variant = variant

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

create_scope :: proc(kind: Scope_Kind, offset := -1) -> ^Scope {
    new_scope := new(Scope)
    new_scope.kind = kind
    new_scope.update_offset = offset

    switch kind {
    case .Global:
    case .Procedure:
    case .Var_Decl:
    case .If:
        assert(offset != -1)
    case .If_Else:
        assert(offset != -1)
    }
    return new_scope
}

push_scope :: proc(new_scope: ^Scope) {
    assert(new_scope != nil)

    switch new_scope.kind {
    case .Global:
    case .Procedure:
        new_scope.stack = new(Stack, context.temp_allocator)
    case .Var_Decl:
        new_scope.stack = new(Stack, context.temp_allocator)
    case .If:
        new_scope.stack = new(Stack, context.temp_allocator)
        for s in compiler.current_scope.stack {
            append(new_scope.stack, s)
        }
    case .If_Else:
        new_scope.stack = new(Stack, context.temp_allocator)
        for s in compiler.current_scope.stack {
            append(new_scope.stack, s)
        }
    }

    new_scope.parent = compiler.current_scope
    compiler.current_scope = new_scope
}

pop_scope :: proc() -> ^Scope {
    old_scope := compiler.current_scope
    compiler.current_scope = old_scope.parent
    return old_scope
}

push_procedure :: proc(procedure: ^Procedure) {
    procedure.parent = compiler.current_proc
    compiler.current_proc = procedure
    push_scope(procedure.scope)
}

pop_procedure :: proc() {
    compiler.current_proc = compiler.current_proc.parent
    pop_scope()
}

are_stacks_equals :: proc(t: Token, a, b: ^Stack, name: string) -> bool {
    if len(a) != len(b) {
        checker_error(t, STACK_SIZE_CHANGED, name)
        return false
    }

    for i in 0..<len(a) {
        if a[i] != b[i] {
            checker_error(
                t, STACK_COMP_CHANGED, name, i + 1,
                a[i].name, b[i].name,
            )
            return false
        }
    }

    return true
}
