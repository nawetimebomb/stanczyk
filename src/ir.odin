package main

Binary_Operation :: enum u8 {
    and, or,
    plus, divide, minus, multiply, modulo,
    ge, gt, le, lt, eq, ne,
}

If_Operation :: enum u8 {
    if_start, elif_start, else_start, if_end,
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

Op_Push_Quotation :: struct {
    value: string,
}

Op_Apply :: struct {}

Op_Binary :: struct {
    operation: Binary_Operation,
}

Op_Call_Proc :: struct {
    ip: int,
    name: string,
}

Op_Cast :: struct {
    to: Type,
}

Op_Describe_Type :: struct {
    type: Type,
}

Op_Drop :: struct {}

Op_Dup :: struct {}

Op_If_Statement :: struct {
    operation: If_Operation,
}

Op_Print :: struct {
    operand: Type,
    newline: bool,
}

Op_Swap :: struct {}

Op_Unary :: struct {
    operand: Type,
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
    Op_Push_Quotation,

    Op_Apply,
    Op_Binary,
    Op_Call_Proc,
    Op_Cast,
    Op_Describe_Type,
    Op_Drop,
    Op_Dup,
    Op_If_Statement,
    Op_Print,
    Op_Swap,
    Op_Unary,
}
