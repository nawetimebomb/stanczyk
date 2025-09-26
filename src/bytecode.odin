package main

import "core:fmt"

Constant_Table :: [dynamic]Constant

Constant :: struct {
    index: int,
    token: Token,
    type:  ^Type,
    value: Constant_Value,
}

Constant_Value :: union {
    bool,
    byte,
    f64,
    i64,
    string,
    u64,
}

Parameter :: struct {
    is_named:   bool, // for named parameters only
    name_token: Token,
    type_token: Token,
    type:       ^Type,
}

Procedure :: struct {
    token:            Token,
    id:               int,
    name:             string,
    is_global:        bool,
    file_info:        ^File_Info,
    entity:           ^Entity,
    scope:            ^Scope,
    parent:           ^Procedure,

    stack:            ^Stack,

    arguments:        []Parameter,
    results:          []Parameter,

    stack_frame_size: int,
    code:             [dynamic]^Instruction,
}

Instruction :: struct {
    offset:    int,
    quoted:    bool,
    token:     Token,
    variant:   Instruction_Variant,
}

Instruction_Variant :: union {
    BINARY_ADD,
    BINARY_DIVIDE,
    BINARY_MINUS,
    BINARY_MULTIPLY,
    BINARY_MODULO,
    CAST,
    COMPARE_EQUAL,
    COMPARE_NOT_EQUAL,
    COMPARE_GREATER,
    COMPARE_GREATER_EQUAL,
    COMPARE_LESS,
    COMPARE_LESS_EQUAL,
    DROP,
    DUP,
    DUP_PREV,
    IDENTIFIER,
    IF_ELSE_JUMP,
    IF_END,
    IF_FALSE_JUMP,
    INVOKE_PROC,
    LEN,
    NIP,
    OVER,
    PRINT,
    PUSH_BIND,
    PUSH_BOOL,
    PUSH_BYTE,
    PUSH_CONST,
    PUSH_FLOAT,
    PUSH_INT,
    PUSH_STRING,
    PUSH_TYPE,
    PUSH_UINT,
    PUSH_VAR_GLOBAL,
    PUSH_VAR_LOCAL,
    RETURN,
    RETURN_VALUE,
    RETURN_VALUES,
    ROTATE_LEFT,
    ROTATE_RIGHT,
    SET,
    STORE_BIND,
    STORE_VAR_GLOBAL,
    STORE_VAR_LOCAL,
    SWAP,
    TUCK,
}

BINARY_ADD :: struct {
    type: ^Type,
}

BINARY_DIVIDE :: struct {
    type: ^Type,
}

BINARY_MINUS :: struct {
    type: ^Type,
}

BINARY_MULTIPLY :: struct {
    type: ^Type,
}

BINARY_MODULO :: struct {
    type: ^Type,
}

CAST :: struct {

}

COMPARE_EQUAL :: struct {
    type: ^Type,
}

COMPARE_NOT_EQUAL :: struct {
    type: ^Type,
}

COMPARE_GREATER :: struct {
    type: ^Type,
}

COMPARE_GREATER_EQUAL :: struct {
    type: ^Type,
}

COMPARE_LESS :: struct {
    type: ^Type,
}

COMPARE_LESS_EQUAL :: struct {
    type: ^Type,
}

DROP :: struct {

}

DUP :: struct {

}

DUP_PREV :: struct {

}

IDENTIFIER :: struct {
    value: string,
}

IF_ELSE_JUMP :: struct {
    jump_offset: int,
}

IF_END :: struct {

}

IF_FALSE_JUMP :: struct {
    jump_offset: int,
    local_scope: ^Scope,
}

INVOKE_PROC :: struct {
    arguments: []^Type,
    results:   []^Type,
    procedure: ^Procedure,
}

LEN :: struct {
    type: ^Type,
}

NIP :: struct {

}

OVER :: struct {

}

PRINT :: struct {
    type: ^Type,
}

PUSH_BIND :: struct {
    offset: int,
    type:   ^Type,
}

PUSH_BOOL :: struct {
    value: bool,
}

PUSH_BYTE :: struct {
    value: byte,
}

PUSH_CONST :: struct {
    const: Entity_Const,
}

PUSH_FLOAT :: struct {
    index: int,
}

PUSH_INT :: struct {
    value: i64,
}

PUSH_STRING :: struct {
    index: int,
}

PUSH_TYPE :: struct {
    value: ^Type,
}

PUSH_UINT :: struct {
    value: u64,
}

PUSH_VAR_GLOBAL :: struct {
    offset: int,
    type:   ^Type,
}

PUSH_VAR_LOCAL :: struct {
    offset: int,
    type:   ^Type,
}

RETURN :: struct {

}

RETURN_VALUE :: struct {

}

RETURN_VALUES :: struct {

}

ROTATE_LEFT :: struct {

}

ROTATE_RIGHT :: struct {

}

SET :: struct {

}

STORE_BIND :: struct {
    offset: int,
    token:  Token,
}

STORE_VAR_GLOBAL :: struct {
    offset: int,
    token:  Token,
}

STORE_VAR_LOCAL :: struct {
    offset: int,
    token:  Token,
}

SWAP :: struct {

}

TUCK :: struct {

}

add_to_constants :: proc(value: Constant_Value) -> int {
    type: ^Type
    index := len(compiler.constants_table)

    switch v in value {
    case bool:
        type = type_bool
    case u8:
        type = type_byte
    case f64:
        type = type_float
    case i64:
        type = type_int
    case string:
        type = type_string
    case u64:
        type = type_uint
    }

    append(&compiler.constants_table, Constant{
        index = index,
        type  = type,
        value = value,
    })
    return index
}

debug_print_bytecode :: proc() {
    _print_params :: proc(params: []Parameter) {
        for p, index in params {
            if p.type != nil {
                fmt.printf("{}", p.type.name)
            } else {
                fmt.printf("TBD({})", p.type_token.text)
            }

            if index < len(params)-1 {
                fmt.printf(" ")
            }
        }
    }

    _signature :: proc(procedure: ^Procedure) {
        _print_params(procedure.arguments)

        if len(procedure.results) > 0 {
            fmt.printf(" --- ")
            _print_params(procedure.results)
        }
    }

    _name :: proc(name: string) {
        fmt.printf("%-20s", name)
    }

    _value :: proc(format: string, args: ..any) {
        msg := fmt.tprintf(format, ..args)
        fmt.printf("%-16s", msg)
    }

    for procedure in bytecode {
        fmt.print(CYAN_BOLD)
        fmt.print("===")
        fmt.printf(" {}", procedure.name)
        fmt.print(" (")
        _signature(procedure)
        fmt.printfln(") ===")
        fmt.print(RESET)

        for instruction, index in procedure.code {
            fmt.printf("(%4d)\t", index)

            switch v in instruction.variant {
            case BINARY_ADD:
                _name("BINARY_ADD")
                _value("({})", v.type.name)

            case BINARY_DIVIDE:
                _name("BINARY_DIVIDE")
                _value("({})", v.type.name)

            case BINARY_MINUS:
                _name("BINARY_MINUS")
                _value("({})", v.type.name)

            case BINARY_MULTIPLY:
                _name("BINARY_MULTIPLY")
                _value("({})", v.type.name)

            case BINARY_MODULO:
                _name("BINARY_MODULO")
                _value("({})", v.type.name)

            case CAST:
                _name("CAST")

            case COMPARE_EQUAL:
                _name("COMPARE_EQUAL")
                _value("({})", v.type.name)

            case COMPARE_NOT_EQUAL:
                _name("COMPARE_NOT_EQUAL")
                _value("({})", v.type.name)

            case COMPARE_GREATER:
                _name("COMPARE_GREATER")
                _value("({})", v.type.name)

            case COMPARE_GREATER_EQUAL:
                _name("COMPARE_GREATER_EQUAL")
                _value("({})", v.type.name)

            case COMPARE_LESS:
                _name("COMPARE_LESS")
                _value("({})", v.type.name)

            case COMPARE_LESS_EQUAL:
                _name("COMPARE_LESS_EQUAL")
                _value("({})", v.type.name)

            case DROP:
                _name("DROP")

            case DUP:
                _name("DUP")

            case DUP_PREV:
                _name("DUP_PREV")

            case IDENTIFIER:
                _name("IDENTIFIER")
                _value("{}", v.value)

            case IF_ELSE_JUMP:
                _name("IF_ELSE_JUMP")
                _value("{}", v.jump_offset)

            case IF_END:
                _name("IF_END")

            case IF_FALSE_JUMP:
                _name("IF_FALSE_JUMP")
                _value("{}", v.jump_offset)

            case INVOKE_PROC:
                _name("INVOKE_PROC")
                _value("{}", v.procedure.name)

            case LEN:
                _name("LEN")
                _value("{}", v.type.name)

            case NIP:
                _name("NIP")

            case OVER:
                _name("OVER")

            case PRINT:
                _name("PRINT")
                _value("({})", v.type.name)

            case PUSH_BIND:
                _name("PUSH_BIND")
                _value("{} ({})", v.offset, v.type.name)

            case PUSH_BOOL:
                _name("PUSH_BOOL")
                _value("{}", v.value)

            case PUSH_BYTE:
                _name("PUSH_BYTE")
                _value("{}", v.value)

            case PUSH_CONST:
                _name("PUSH_CONST")
                _value("{}", v.const.value)

            case PUSH_FLOAT:
                _name("PUSH_FLOAT")
                _value("{}", v.index)

            case PUSH_INT:
                _name("PUSH_INT")
                _value("{}", v.value)

            case PUSH_STRING:
                _name("PUSH_STRING")
                _value("{}", v.index)

            case PUSH_TYPE:
                _name("PUSH_TYPE")
                _value("{}", v.value.name)

            case PUSH_UINT:
                _name("PUSH_UINT")
                _value("{}", v.value)

            case PUSH_VAR_GLOBAL:
                _name("PUSH_VAR_GLOBAL")
                _value("{}", v.offset)

            case PUSH_VAR_LOCAL:
                _name("PUSH_VAR_LOCAL")
                _value("{}", v.offset)

            case RETURN:
                _name("RETURN")

            case RETURN_VALUE:
                _name("RETURN_VALUE")

            case RETURN_VALUES:
                _name("RETURN_VALUES")

            case ROTATE_LEFT:
                _name("ROTATE_LEFT")

            case ROTATE_RIGHT:
                _name("ROTATE_RIGHT")

            case SET:
                _name("SET")

            case STORE_BIND:
                _name("STORE_BIND")
                _value("{}", v.token.text)

            case STORE_VAR_GLOBAL:
                _name("STORE_VAR_GLOBAL")
                _value("{}", v.offset)

            case STORE_VAR_LOCAL:
                _name("STORE_VAR_LOCAL")
                _value("{}", v.offset)

            case SWAP:
                _name("SWAP")

            case TUCK:
                _name("TUCK")
            }

            fmt.println()
        }

        fmt.println()
    }
}
