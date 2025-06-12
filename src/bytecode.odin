package main

Bytecode :: struct {
    using pos: Position,

    address: uint,
    variant: Bytecode_Variant,
}

Bytecode_Variant :: union {
    Push_Bool,
    Push_Bound,
    Push_Byte,
    Push_Cstring,
    Push_Int,
    Push_String,
    Push_Var_Global,
    Push_Var_Local,
    Declare_Var_Global,
    Declare_Var_Local,

    Get_Byte, Set, Set_Byte,

    Add,
    Divide,
    Modulo,
    Multiply,
    Substract,
    Comparison,

    If,
    Else,
    Fi,

    For_Infinite_Start,
    For_Infinite_End,
    For_Range_Start,
    For_Range_End,
    For_String_Start,
    For_String_End,

    Drop,
    Dup,
    Nip,
    Over,
    Rotate,
    Rotate_Neg,
    Swap,
    Tuck,

    Assembly,
    Call_Function,
    Call_C_Function,
    Let_Bind,
    Let_Unbind,
    Return,
}

Comparison_Kind :: enum {
    eq, ge, gt, le, lt, ne,
}

// BEGIN VALUE

Push_Bool :: struct { val: bool }
Push_Bound :: struct { val: int, use_pointer: bool, mutable: bool }
Push_Byte :: struct { val: byte }
Push_Cstring :: struct { val: int, length: int }
Push_Int :: struct { val: int }
Push_String :: struct { val: int }
Push_Var_Global :: struct { val: uint, use_pointer: bool }
Push_Var_Local :: struct { val: uint, use_pointer: bool }
Declare_Var_Global :: struct { offset: uint, kind: Type_Basic_Kind, set: bool }
Declare_Var_Local :: struct { offset: uint, kind: Type_Basic_Kind, set: bool }

// END VALUE

// BEGIN MEMORY

Get_Byte :: struct {}
Set :: struct {}
Set_Byte :: struct {}

// END MEMORY

// BEGIN BINARY

Add :: struct {}
Divide :: struct {}
Modulo :: struct {}
Multiply :: struct {}
Substract :: struct {}
Comparison :: struct { kind: Comparison_Kind, autoincrement: bool, operands: ^Type }

// END BINARY

// BEGIN FLOW CONTROL

If :: struct {}
Else :: struct { address: uint }
Fi :: struct { address: uint }

For_Infinite_Start :: struct {}
For_Infinite_End   :: struct { address: uint }
For_Range_Start :: struct { kind: Comparison_Kind }
For_Range_End   :: struct { address: uint, autoincrement: enum { off, up, down } }

For_String_Start :: struct {}
For_String_End :: struct { address: uint }

// END FLOW CONTROL

// BEGIN STACK

Drop :: struct {}
Dup :: struct {}
Nip :: struct {}
Over :: struct {}
Rotate :: struct {}
Rotate_Neg :: struct {}
Swap :: struct {}
Tuck :: struct {}

// END STUCK

// BEGIN INTRINSICS

Assembly :: struct { code: string }
Call_Function :: struct { address: uint, name: string }
Call_C_Function :: struct { name: string, inputs: int, outputs: int }
Let_Bind :: struct { val: int }
Let_Unbind :: struct { val: int }
Return :: struct {}

// END INTRINSICS

bytecode_to_string :: proc(b: Bytecode) -> string {
    switch v in b.variant {
    case Push_Bool: return "boolean literal"
    case Push_Bound: return "bound value"
    case Push_Byte: return "byte literal"
    case Push_Cstring: return "cstring literal"
    case Push_Int: return "int literal"
    case Push_String: return "string literal"
    case Push_Var_Global: return "global variable value"
    case Push_Var_Local: return "local variable value"
    case Declare_Var_Global: return "declare global variable"
    case Declare_Var_Local: return "declare local variable"

    case Get_Byte: return "get-byte"
    case Set: return "set"
    case Set_Byte: return "set-byte"

    case Add: return "+"
    case Divide: return "/"
    case Modulo: return "%"
    case Multiply: return "*"
    case Substract: return "-"

    case Comparison:
        switch v.kind {
        case .eq: return "="
        case .ge: return ">="
        case .gt: return ">"
        case .le: return "<="
        case .lt: return "<"
        case .ne: return "!="
        }

    case If: return "if"
    case Else: return "else"
    case Fi: return "fi"
    case For_Infinite_Start: return "start of for loop (infinite)"
    case For_Infinite_End: return "end of for loop (infinite)"
    case For_Range_Start: return "start of for loop (range)"
    case For_Range_End: return "end of for loop (range)"
    case For_String_Start: return "start of for loop (string)"
    case For_String_End: return "end of for loop (string)"

    case Drop: return "drop"
    case Dup: return "dup"
    case Nip: return "nip"
    case Over: return "over"
    case Rotate: return "rot"
    case Rotate_Neg: return "-rot"
    case Swap: return "swap"
    case Tuck: return "tuck"

    case Assembly: return "assembly code block"
    case Call_Function: return "call function"
    case Call_C_Function: return "call C function"
    case Let_Bind: return "let binding scope starts"
    case Let_Unbind: return "let binding scope ends"
    case Return: return "return or implicit ';'"
    }

    assert(false)
    return "invalid"
}
