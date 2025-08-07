package main

// NOTE: Not used yet but keep as a demo
// add_builtin_procedure :: proc(name: string) {
//     switch name {
//     case "print":   fallthrough
//     case "println":
//         variant := Entity_Procedure{}
//         node := create_node()
//         node.type = new_clone(Type{
//             size = 8,
//             variant = Type_Any{autocast_type = type_from_string("string")},
//         })
//         node.variant = Ast_Identifier{}

//         append(&variant.params, node)
//         append(&parser.global_scope.entities, Entity{
//             foreign_name = name,
//             is_builtin   = true,
//             is_global    = true,
//             name         = name,
//             variant      = variant,
//         })
//     case: unimplemented()
//     }
// }
