package main

Bytecode :: struct {
    using pos: Position,

    address: uint,
    variant: Bytecode_Variant,
}

Bytecode_Variant :: union {
    Push_Bool,
    Push_Bound,
    Push_Bound_Pointer,
    Push_Byte,
    Push_Cstring,
    Push_Int,
    Push_String,
    Push_Var_Global,
    Push_Var_Global_Pointer,
    Push_Var_Local,
    Push_Var_Local_Pointer,

    Get, Get_Byte,
    Set, Set_Byte,

    Add,
    Divide,
    Modulo,
    Multiply,
    Substract,

    Equal,
    Greater,
    Greater_Equal,
    Less,
    Less_Equal,
    Not_Equal,

    If,
    Else,
    Fi,
    Do,
    For_Range,
    Loop,

    Assembly,
    Call_Function,
    Call_C_Function,
    Let_Bind,
    Let_Unbind,
    Let_Rebind,
    Print,
    Return,
}

// BEGIN PUSH OPs

Push_Bool :: struct { val: bool }
Push_Bound :: struct { val: int }
Push_Bound_Pointer :: struct { val: int }
Push_Byte :: struct { val: byte }
Push_Cstring :: struct { val: int, length: int }
Push_Int :: struct { val: int }
Push_String :: struct { val: int }
Push_Var_Global :: struct { val: uint }
Push_Var_Global_Pointer :: struct { val: uint }
Push_Var_Local :: struct { val: uint }
Push_Var_Local_Pointer :: struct { val: uint }

Get :: struct {}
Get_Byte :: struct {}
Set :: struct {}
Set_Byte :: struct {}

// BEGIN ARITHMETIC OPs

Add :: struct {}
Divide :: struct {}
Modulo :: struct {}
Multiply :: struct {}
Substract :: struct {}

// BEGIN COMPARISON OPs

Equal :: struct {}
Greater :: struct {}
Greater_Equal :: struct {}
Less :: struct {}
Less_Equal :: struct {}
Not_Equal :: struct {}

// BEGIN FLOW CONTROL OPs
If :: struct {}
Else :: struct { address: uint }
Fi :: struct { address: uint }
Do :: struct { use_self: bool, address: uint }
For_Range :: struct {}
Loop :: struct { address: uint, bindings: int }

// BEGIN INTRINSIC OPs

Assembly :: struct { code: string }
Call_Function :: struct { address: uint, name: string }
Call_C_Function :: struct { name: string, inputs: int, outputs: int }
Let_Bind :: struct { val: int }
Let_Unbind :: struct { val: int }
Let_Rebind :: struct { val: int }
Print :: struct {}
Return :: struct {}

bytecode_to_string :: proc(b: Bytecode) -> string {
    switch v in b.variant {
    case Push_Bool: return "boolean literal"
    case Push_Bound: return "bound value"
    case Push_Bound_Pointer: return "bound pointer"
    case Push_Byte: return "byte literal"
    case Push_Cstring: return "cstring literal"
    case Push_Int: return "int literal"
    case Push_String: return "string literal"
    case Push_Var_Global: return "global variable value"
    case Push_Var_Global_Pointer: return "global variable pointer"
    case Push_Var_Local: return "local variable value"
    case Push_Var_Local_Pointer: return "local variable pointer"

    case Get: return "get"
    case Get_Byte: return "get-byte"
    case Set: return "set"
    case Set_Byte: return "set-byte"

    case Add: return "+"
    case Divide: return "/"
    case Modulo: return "%"
    case Multiply: return "*"
    case Substract: return "-"

    case Equal: return "="
    case Greater: return ">"
    case Greater_Equal: return ">="
    case Less: return "<"
    case Less_Equal: return "<="
    case Not_Equal: return "!="

    case If: return "if"
    case Else: return "else"
    case Fi: return "fi"
    case Do: return "do"
    case For_Range: return "for (range)"
    case Loop: return "loop"

    case Assembly: return "assembly code block"
    case Call_Function: return "call function"
    case Call_C_Function: return "call C function"
    case Let_Bind: return "let binding scope starts"
    case Let_Unbind: return "let binding scope ends"
    case Let_Rebind: return "let binding rebound"
    case Print: return "print"
    case Return: return "return (implicitly ;)"
    }

    assert(false)
    return "invalid"
}
