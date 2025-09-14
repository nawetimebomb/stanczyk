package main

import "core:fmt"

Value :: union {
    bool,
    f64,
    i64,
    u64,
    string,
    ^Type,
}

Register :: struct {
    prefix: string,
    ip:     int,
    type:   ^Type,
}

Binary :: struct {
    lhs: ^Register,
    rhs: ^Register,
}

Op_Code :: struct {
    ip:        int,
    register:  ^Register,
    token:     Token,

    type:      ^Type,
    value:     Value,
    variant:   Op_Variant,
}

Op_Variant :: union {
    // unsure what to do here, depends on type checking to
    // figure out if this is proc call, a variable or the like.
    Op_Identifier,

    Op_Constant,
    Op_Plus,
    Op_Proc_Call,
    Op_Return,

    Op_Proc_Decl,

    Op_Type_Lit,

    Op_Drop,
    Op_Binary_Expr,
}

Op_Identifier :: struct {
    value: Token,
}



Op_Constant :: struct {

}

Op_Plus :: struct {
    using binary: Binary,
}

Op_Proc_Call :: struct {
    arguments:    []^Op_Code,
    results:      []^Op_Code,
    entity:       ^Entity,
    foreign_name: string,
}

Op_Return :: struct {
    results: []^Op_Code,
}



Op_Proc_Decl :: struct {
    name:         Token,
    foreign_name: string,
    is_foreign:   bool,
    foreign_lib:  Token,

    scope:        ^Scope,
    entity:       ^Entity,

    registers:    map[^Type][dynamic]Register,
    arguments:    []^Op_Code,
    results:      []^Op_Code,
    body:         [dynamic]^Op_Code,
}

Op_Type_Lit :: struct {}


Op_Drop :: struct {

}

Op_Binary_Expr :: struct {
    lhs: ^Register,
    rhs: ^Register,
    op:  string,
}
