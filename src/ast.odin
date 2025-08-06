package main

import "core:strings"

Value :: union {
    bool, f64, i64, u64, string,
}

Ast :: struct {
    token:   Token,
    type:    ^Type,
    value:   Value,
    variant: Ast_Variant,
}

Ast_Variant :: union {
    Ast_Identifier,
    Ast_Literal,
    Ast_Proc_Call,
    Ast_Proc_Decl,
    Ast_Return,
}

Ast_Identifier :: struct {
    foreign_name: string,
    name: string,
}

Ast_Literal :: struct {}

Ast_Proc_Call :: struct {
    foreign_name: string,
    is_builtin:   bool,
    params:       []^Ast,
}

Ast_Proc_Decl :: struct {
    body:         [dynamic]^Ast,
    foreign_name: string,
    name:         string,
    params:       []^Ast,
    scope:        ^Scope,

    is_inline: bool,
}

Ast_Return :: struct {

}

value_to_string :: proc(value: Value) -> string {
    if v, ok := value.(string); ok {
        return v
    }

    if v, ok := value.(bool); ok {
        return v ? "true" : "false"
    }

    result := strings.builder_make()

    #partial switch v in value {
        case f64: strings.write_f64(&result, v, 'f')
        case i64: strings.write_i64(&result, v)
        case u64: strings.write_u64(&result, v)
    }

    return strings.to_string(result)
}
