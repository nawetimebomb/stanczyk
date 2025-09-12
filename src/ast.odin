package main

import "core:strings"

Ast :: struct {
    token:      Token,
    type:       ^Type,
    value:      Value,
    variant:    Ast_Variant,
}

Value :: union {
    bool,
    f64,
    i64,
    u64,
    string,
}

Ast_Variant :: union {
    Ast_Builtin,

    Ast_Basic_Literal,
    Ast_Binary,
    Ast_Block,
    Ast_Proc_Decl,
}

Ast_Basic_Literal :: struct {
    token: Token,
}

Ast_Binary :: struct {
    lhs: ^Ast,
    rhs: ^Ast,
    op:  string,
}

Ast_Block :: struct {
    open:  Token,
    close: Token,
    body:  [dynamic]^Ast,
}

Ast_Builtin :: struct {
    cname:     string,
    arguments: []^Ast,
}

Ast_Proc_Decl :: struct {
    name:      string,
    cname:     string,
    body:      ^Ast,
    type:      ^Ast,

    entity:    ^Entity,
    scope:     ^Scope,
}

Ast_Proc_Type :: struct {
    arguments: []^Ast,
    results:   []^Ast,
}

// TODO(nawe) make this actually call to a proc declaration
Ast_Proc_Call :: struct {
    procedure: ^Ast,
    entity:    ^Entity,
    arguments: []^Ast,
}

values_are_literal :: proc(v1, v2: ^Ast) -> bool {
    _, ok := v1.variant.(Ast_Basic_Literal)
    if !ok do return false
    _, ok = v2.variant.(Ast_Basic_Literal)
    return ok
}
