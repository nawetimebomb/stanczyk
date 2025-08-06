package main

add_builtin_procedure :: proc(name: string) {
    switch name {
    case "print":   fallthrough
    case "println":
        variant := Entity_Procedure{}
        node := create_node()
        node.type = type_from_string("any")
        node.variant = Ast_Identifier{}

        append(&variant.params, node)
        append(&parser.global_scope.entities, Entity{
            foreign_name = name,
            is_global = true,
            name = name,
            variant = variant,
        })
    case: unimplemented()
    }
}
