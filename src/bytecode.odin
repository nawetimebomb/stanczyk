package main

import "core:fmt"

Parameter :: struct {
    is_named:   bool, // for named parameters only
    name_token: Token,
    type_token: Token,
    type:       ^Type,
}

Procedure :: struct {
    token:        Token,
    name:         string,
    foreign_name: string,
    is_global:    bool,
    file_info:    ^File_Info,
    entity:       ^Entity,
    scope:        ^Scope,
    parent:       ^Procedure,

    registers:    [dynamic]^Register,
    arguments:    []Parameter,
    results:      []Parameter,

    code:         [dynamic]^Instruction,
}

Register :: struct {
    index:   int,
    mutable: bool,
    type:    ^Type,
}

Instruction :: struct {
    register:  ^Register, // in case it has an associated register
    offset:    int,
    token:     Token,
    variant:   Instruction_Variant,
}

Instruction_Variant :: union {
    BINARY_ADD,
    BINARY_MINUS,
    BINARY_MULTIPLY,
    BINARY_MODULO,
    BINARY_SLASH,
    CAST,
    COMPARE_EQUAL,
    COMPARE_NOT_EQUAL,
    COMPARE_GREATER,
    COMPARE_GREATER_EQUAL,
    COMPARE_LESS,
    COMPARE_LESS_EQUAL,
    DECLARE_VAR_END,
    DECLARE_VAR_START,
    DROP,
    DUP,
    DUP_PREV,
    IDENTIFIER,
    INVOKE_PROC,
    NIP,
    OVER,
    PRINT,
    PUSH_ARG,
    PUSH_BIND,
    PUSH_BOOL,
    PUSH_BYTE,
    PUSH_CONST,
    PUSH_FLOAT,
    PUSH_INT,
    PUSH_STRING,
    PUSH_TYPE,
    PUSH_UINT,
    RETURN,
    RETURN_VALUE,
    RETURN_VALUES,
    ROTATE_LEFT,
    ROTATE_RIGHT,
    STORE_BIND,
    STORE_VAR,
    SWAP,
    TUCK,
}

BINARY_ADD :: struct {
    lhs: ^Register,
    rhs: ^Register,
}

BINARY_MINUS :: struct {
    lhs: ^Register,
    rhs: ^Register,
}

BINARY_MULTIPLY :: struct {
    lhs: ^Register,
    rhs: ^Register,
}

BINARY_MODULO :: struct {
    lhs: ^Register,
    rhs: ^Register,
}

BINARY_SLASH :: struct {
    lhs: ^Register,
    rhs: ^Register,
}

CAST :: struct {

}

COMPARE_EQUAL :: struct {
    lhs: ^Register,
    rhs: ^Register,
}

COMPARE_NOT_EQUAL :: struct {
    lhs: ^Register,
    rhs: ^Register,
}

COMPARE_GREATER :: struct {
    lhs: ^Register,
    rhs: ^Register,
}

COMPARE_GREATER_EQUAL :: struct {
    lhs: ^Register,
    rhs: ^Register,
}

COMPARE_LESS :: struct {
    lhs: ^Register,
    rhs: ^Register,
}

COMPARE_LESS_EQUAL :: struct {
    lhs: ^Register,
    rhs: ^Register,
}

DECLARE_VAR_END :: struct {
    token: Token,
}

DECLARE_VAR_START :: struct {
    token: Token,
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

INVOKE_PROC :: struct {
    arguments: []^Register,
    results:   []^Register,
    procedure: ^Procedure,
}

NIP :: struct {

}

OVER :: struct {

}

PRINT :: struct {
    param: ^Register,
}

PUSH_ARG :: struct {
    value: int,
}

PUSH_BIND :: struct {
    value: ^Register,
}

PUSH_BOOL :: struct {
    value: bool,
}

PUSH_BYTE :: struct {
    value: u8,
}

PUSH_CONST :: struct {
    const: Entity_Const,
}

PUSH_FLOAT :: struct {
    value: f64,
}

PUSH_INT :: struct {
    value: i64,
}

PUSH_STRING :: struct {
    value: string,
}

PUSH_TYPE :: struct {
    value: ^Type,
}

PUSH_UINT :: struct {
    value: u64,
}

RETURN :: struct {

}

RETURN_VALUE :: struct {
    value: ^Register,
}

RETURN_VALUES :: struct {
    value: []^Register,
}

ROTATE_LEFT :: struct {

}

ROTATE_RIGHT :: struct {

}

STORE_BIND :: struct {
    token: Token,
}

STORE_VAR :: struct {
    lvalue: ^Register, // the register with the mutable variable
    rvalue: ^Register, // the value side
}

SWAP :: struct {

}

TUCK :: struct {

}

REGISTER :: proc(type: ^Type, ins: ^Instruction = nil) -> ^Register {
    result := new(Register)
    result.index = len(compiler.current_proc.registers)
    result.type = type
    append(&compiler.current_proc.registers, result)

    if ins != nil {
        assert(ins.register == nil)
        ins.register = result
    }

    return result
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
        fmt.printf("%-16s", name)
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
                _value("r{} + r{}", v.lhs, v.rhs)

            case BINARY_MINUS:
                _name("BINARY_MINUS")
                _value("r{} - r{}", v.lhs, v.rhs)

            case BINARY_MULTIPLY:
                _name("BINARY_MULTIPLY")
                _value("r{} * r{}", v.lhs, v.rhs)

            case BINARY_MODULO:
                _name("BINARY_MODULO")
                _value("r{} % r{}", v.lhs, v.rhs)

            case BINARY_SLASH:
                _name("BINARY_SLASH")
                _value("r{} / r{}", v.lhs, v.rhs)

            case CAST:
                _name("CAST")

            case COMPARE_EQUAL:
                _name("COMPARE_EQUAL")

            case COMPARE_NOT_EQUAL:
                _name("COMPARE_NOT_EQUAL")

            case COMPARE_GREATER:
                _name("COMPARE_GREATER")

            case COMPARE_GREATER_EQUAL:
                _name("COMPARE_GREATER_EQUAL")

            case COMPARE_LESS:
                _name("COMPARE_LESS")

            case COMPARE_LESS_EQUAL:
                _name("COMPARE_LESS_EQUAL")

            case DECLARE_VAR_END:
                _name("DECLARE_VAR_END")
                _value("{}", v.token.text)

            case DECLARE_VAR_START:
                _name("DECLARE_VAR_START")
                _value("{}", v.token.text)

            case DROP:
                _name("DROP")

            case DUP:
                _name("DUP")

            case DUP_PREV:
                _name("DUP_PREV")

            case IDENTIFIER:
                _name("IDENTIFIER")
                _value("{}", v.value)

            case INVOKE_PROC:
                _name("INVOKE_PROC")
                _value("{}({})", v.procedure.name, v.arguments)

            case NIP:
                _name("NIP")

            case OVER:
                _name("OVER")

            case PRINT:
                _name("PRINT")
                _value("r{} (type: {})", v.param.index, v.param.type.name)

            case PUSH_ARG:
                _name("PUSH_ARG")
                _value("arg{}", v.value)

            case PUSH_BIND:
                _name("PUSH_BIND")
                _value("{}", v.value.index)

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
                _value("{}", v.value)

            case PUSH_INT:
                _name("PUSH_INT")
                _value("{}", v.value)

            case PUSH_STRING:
                _name("PUSH_STRING")
                _value("{}", v.value)

            case PUSH_TYPE:
                _name("PUSH_TYPE")
                _value("{}", v.value.name)

            case PUSH_UINT:
                _name("PUSH_UINT")
                _value("{}", v.value)

            case RETURN:
                _name("RETURN")

            case RETURN_VALUE:
                _name("RETURN_VALUE")
                _value("r{}", v.value)

            case RETURN_VALUES:
                _name("RETURN_VALUES")
                _value("{}", v.value)

            case ROTATE_LEFT:
                _name("ROTATE_LEFT")

            case ROTATE_RIGHT:
                _name("ROTATE_RIGHT")

            case STORE_BIND:
                _name("STORE_BIND")
                _value("{}", v.token.text)

            case STORE_VAR:
                _name("STORE_VAR")

            case SWAP:
                _name("SWAP")

            case TUCK:
                _name("TUCK")
            }

            if instruction.register != nil {
                fmt.printf("\t-> {}", instruction.register.index)
            }
            fmt.println()
        }

        fmt.println()
    }
}
