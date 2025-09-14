package main

register_builtin_print_entity :: proc() {
    op := create_op_code(make_token("proc"))
    arg := create_op_code(make_token("int"))
    arg.type = compiler.basic_types[.Int]
    arg.variant = Op_Type_Lit{}
    arguments := make([dynamic]^Op_Code)
    append(&arguments, arg)

    op.variant = Op_Proc_Decl{
        name = make_token("internal_print"),
        foreign_name = "internal_print",
        scope = create_scope(op),
        entity = create_entity("print", op, Entity_Procedure{}),
        arguments = arguments[:],
    }
}
