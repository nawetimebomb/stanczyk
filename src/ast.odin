package main

import "core:strings"

Value :: union {
    bool, f64, i64, u64, string,
}

Ast :: struct {
    pushed_to_stack: bool,
    token:           Token,
    type:            ^Type,
    value:           Value,
    variant:         Ast_Variant,
}

Ast_Variant :: union {
    Ast_Assign,
    Ast_Binary,
    Ast_Identifier,
    Ast_Literal,
    Ast_Proc_Call,
    Ast_Proc_Decl,
    Ast_Result_Decl,
    Ast_Return,
    Ast_Variable_Decl,
}

Ast_Assign :: struct {
    assignee: ^Ast,
    value:    ^Ast,
    operator: string,
}

Ast_Binary :: struct {
    left: ^Ast,
    name: ^Ast,
    operator: string,
    right: ^Ast,
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
    results:      []^Ast,
    scope:        ^Scope,
}

Ast_Result_Decl :: struct {
    types: []^Ast,
    name:  ^Ast,
    value: ^Ast,
}

Ast_Return :: struct {
    params: []^Ast,
}

Ast_Variable_Decl :: struct {
    is_global: bool,
    name:      ^Ast,
    value:     ^Ast,
}

value_to_string :: proc(value: Value) -> string {
    result := strings.builder_make()

    switch v in value {
    case bool: strings.write_string(&result, v ? "true" : "false")
    case f64:  strings.write_f64(&result, v, 'f')
    case i64:  strings.write_i64(&result, v)
    case u64:  strings.write_u64(&result, v)
    case string:
        for r in v {
            strings.write_escaped_rune(&result, r, '\\')
        }
    }

    return strings.to_string(result)
}
