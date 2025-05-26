package main

Procedure :: struct {
    addr:       uint,
    loc:        Location,
    name:       string,
    module:     string,
    token:      Token,
    // entities:   Entity_Table,
    ops:        [dynamic]Operation,
    convention: Calling_Convention,
    parent:     ^Procedure,
    internal:   bool,

    params:     Arity,
    results:    Arity,

    called:     bool,
    errored:    bool,
    inlined:    bool,
    simulated:  bool,
}

Arity :: distinct [dynamic]Type

Program :: struct {
    procedures: map[string]Procedure,
    quotes:     [dynamic]Procedure,
}

Binary_Operation :: enum u8 {
    and, or,
    plus, divide, minus, multiply, modulo,
    ge, gt, le, lt, eq, ne,
}

Unary_Operation :: enum u8 {
    minus_minus, plus_plus,
}

Op_Push_Bool :: struct {
    value: bool,
}

Op_Push_Float :: struct {
    value: f64,
}

Op_Push_Integer :: struct {
    value: int,
}

Op_Push_String :: struct {
    value: string,
}

Op_Push_Quote :: struct {
    contents: string,
    procedure: ^Procedure,
}

Op_Push_Type :: struct {
    value: string,
}

Op_Apply :: struct {}

Op_Binary :: struct {
    operation: Binary_Operation,
}

Op_Call_Proc :: struct {
    addr: uint,
    name: string,
}

Op_Cast :: struct {}

Op_Drop :: struct {}

Op_Dup :: struct {}

Op_If :: struct {
    has_else: bool,
}

Op_Print :: struct {
    newline: bool,
}

Op_Swap :: struct {}

Op_Times :: struct {}

Op_Typeof :: struct {}

Op_Unary :: struct {
    operation: Unary_Operation,
}

Operation :: struct {
    variant: Operation_Variant,
    loc:  Location,
}

Operation_Variant :: union {
    Op_Push_Bool,
    Op_Push_Float,
    Op_Push_Integer,
    Op_Push_String,
    Op_Push_Quote,
    Op_Push_Type,

    Op_Apply,
    Op_Binary,
    Op_Call_Proc,
    Op_Cast,
    Op_Drop,
    Op_Dup,
    Op_If,
    Op_Print,
    Op_Swap,
    Op_Times,
    Op_Typeof,
    Op_Unary,
}
