package main

import "core:reflect"

Stack :: distinct [dynamic]^Register

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
    value: ^Register,
}

Entity_Const :: struct {
    type:  ^Type,
    value: Value_Const,
}

Entity_Proc :: struct {
    procedure: ^Procedure,
}

Entity_Type :: struct {
    type: ^Type,
}

Entity_Var :: struct {
    value: ^Register,
}

Scope :: struct {
    entities: [dynamic]^Entity,
    parent:   ^Scope,
    kind:     Scope_Kind,
    stack:    ^Stack,
}

Scope_Kind :: enum u8 {
    Global,
    Procedure,
    Var_Decl,
}

Value_Const :: union {
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

create_scope :: proc(kind: Scope_Kind) -> ^Scope {
    new_scope := new(Scope)
    switch kind {
    case .Global:
    case .Procedure:
        new_scope.stack = new(Stack)
    case .Var_Decl:
        new_scope.stack = new(Stack, context.temp_allocator)
    }
    return new_scope
}

push_scope :: proc(new_scope: ^Scope) {
    assert(new_scope != nil)

    switch new_scope.kind {
    case .Global:
    case .Procedure:
    case .Var_Decl:
    }

    new_scope.parent = compiler.current_scope
    compiler.current_scope = new_scope
}

pop_scope :: proc() {
    old_scope := compiler.current_scope
    compiler.current_scope = old_scope.parent

    switch old_scope.kind {
    case .Global:
    case .Procedure:
    case .Var_Decl:
        free(old_scope.stack)
    }
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
