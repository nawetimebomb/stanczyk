package main

NativeFunctionId :: enum {
    PRINT_STATEMENT,
}

NativeFunctionDefinition :: struct {
    arguments: []DataType,
    returns: []DataType,
}

native_fns := map[Token_Type]NativeFunctionDefinition{
        .PRINT = {
            arguments = { .ANY, },
            returns = {},
        },
}

get_native_fn :: proc(tt: Token_Type) -> NativeFunctionDefinition {
    return native_fns[tt]
}
