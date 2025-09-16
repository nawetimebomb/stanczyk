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
    index: int,
    type:  ^Type,
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
    DROP,
    DUP,
    IDENTIFIER,
    INVOKE_PROC,
    PRINT,
    PUSH_ARG,
    PUSH_FLOAT,
    PUSH_INT,
    PUSH_TYPE,
    PUSH_UINT,
    RETURN,
    RETURN_VALUE,
    RETURN_VALUES,
}

BINARY_ADD :: struct {
    lhs: int, // index to the register stack
    rhs: int,
}

BINARY_MINUS :: struct {
    lhs: int,
    rhs: int,
}

BINARY_MULTIPLY :: struct {
    lhs: int,
    rhs: int,
}

BINARY_MODULO :: struct {
    lhs: int,
    rhs: int,
}

BINARY_SLASH :: struct {
    lhs: int,
    rhs: int,
}

CAST :: struct {

}

DROP :: struct {

}

DUP :: struct {

}

IDENTIFIER :: struct {
    value: string,
}

INVOKE_PROC :: struct {
    arguments: []^Register,
    results:   []^Register,
    procedure: ^Procedure,
}

PRINT :: struct {
    param: ^Register,
}

PUSH_ARG :: struct {
    value: int,
}

PUSH_FLOAT :: struct {
    value: f64,
}

PUSH_INT :: struct {
    value: i64,
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
    value: int,
}

RETURN_VALUES :: struct {
    value: []^Register,
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

            case DROP:
                _name("DROP")

            case DUP:
                _name("DUP")

            case IDENTIFIER:
                _name("IDENTIFIER")
                _value("{}", v.value)

            case INVOKE_PROC:
                _name("INVOKE_PROC")
                _value("{}({})", v.procedure.name, v.arguments)

            case PRINT:
                _name("PRINT")
                _value("r{} (type: {})", v.param.index, v.param.type.name)

            case PUSH_ARG:
                _name("PUSH_ARG")
                _value("arg{}", v.value)

            case PUSH_FLOAT:
                _name("PUSH_FLOAT")
                _value("{}", v.value)

            case PUSH_INT:
                _name("PUSH_INT")
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
            }

            if instruction.register != nil {
                fmt.printf("\t-> {}", instruction.register.index)
            }
            fmt.println()
        }

        fmt.println()
    }
}
