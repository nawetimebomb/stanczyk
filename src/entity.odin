package main

Entity :: struct {
    name:    string,
    variant: Entity_Variant,
}

Entity_Variant :: union {
    Entity_Procedure,
    Entity_Type,
}

Entity_Procedure :: struct {
    procedure: ^Procedure,
}

Entity_Type :: struct {
    type: ^Type,
}

Scope :: struct {
    entities: [dynamic]^Entity,
    parent:   ^Scope,
}

create_entity :: proc(name: string, variant: Entity_Variant) -> ^Entity {
    entity := new(Entity)
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

create_scope :: proc() -> ^Scope {
    new_scope := new(Scope)
    return new_scope
}

push_scope :: proc(new_scope: ^Scope) {
    assert(new_scope != nil)
    new_scope.parent = compiler.current_scope
    compiler.current_scope = new_scope
}

pop_scope :: proc() {
    old_scope := compiler.current_scope
    compiler.current_scope = old_scope.parent
}

push_procedure :: proc(procedure: ^Procedure) {
    procedure.parent = compiler.curr_proc
    compiler.curr_proc = procedure
    push_scope(procedure.scope)
}

pop_procedure :: proc() {
    compiler.curr_proc = compiler.curr_proc.parent
    pop_scope()
}
