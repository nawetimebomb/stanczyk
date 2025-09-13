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

Op_Code :: struct {
    local_ip:  int,
    register:  ^Register,
    token:     Token,

    type:      ^Type,
    value:     Value,
    variant:   Op_Variant,
}

Op_Variant :: union {
    Op_Push_Constant,
    Op_Proc_Decl,

    Op_Identifier, // unsure what to do, depends on type checking

    Op_Type_Lit,

    Op_Binary_Expr,


    Op_Return,
}

Op_Push_Constant :: struct {}

Op_Proc_Decl :: struct {
    name:        Token,
    cname:       string,
    is_foreign:  bool,
    foreign_lib: Token,

    scope:       ^Scope,
    entity:      ^Entity,

    registers:   map[^Type][dynamic]Register,
    arguments:   []^Op_Code,
    results:     []^Op_Code,
    body:        [dynamic]^Op_Code,
}

Op_Return :: struct {
    results: []^Op_Code,
}

Op_Identifier :: struct {
    value: Token,
}

Op_Type_Lit :: struct {}


Op_Binary_Expr :: struct {
    lhs: ^Register,
    rhs: ^Register,
    op:  string,
}



print_op_debug :: proc(op: ^Op_Code, level := 0) {
    print_op_name :: proc(s: string) {
        fmt.printf(" %-15s ", s)
    }

    print_op_type :: proc(op: ^Op_Code) {
        fmt.printf(" {} ", type_to_string(op.type))
    }

    print_op_value :: proc(op: ^Op_Code) {
        fmt.printf(" {} ", op.value)
    }

    print_prefix :: proc(level: int) {
        TABS := "\t\t\t\t\t\t\t\t\t\t\t\t\t"
        prefix := TABS[:level]
        fmt.printf("{}", prefix)
    }

    print_prefix(level)

    fmt.printf("(%4d) ", op.local_ip)
    switch variant in op.variant {
    case Op_Push_Constant:
        print_op_name("PUSH_CONSTANT")
        print_op_type(op)
        print_op_value(op)
        fmt.println()

    case Op_Identifier:
        print_op_name("IDENTIFIER")
        fmt.println(variant.value.text)
    case Op_Type_Lit:
        print_op_name("TYPE")
        fmt.println(type_to_string(op.type))

    case Op_Binary_Expr:
        print_op_name("BINARY_EXPR")
        fmt.println(variant.op)
    case Op_Proc_Decl:
        if variant.is_foreign {
            lib_name := variant.foreign_lib.text
            fmt.printf("FOREIGN")
            if len(lib_name) > 0 {
                fmt.printf("({}) ", lib_name)
            } else {
                fmt.print(" ")
            }
        }
        fmt.printf("PROCEDURE \e[1m{}\e[0m ", variant.name.text)

        fmt.printf("(")
        if len(variant.arguments) > 0 {
            for op2, index in variant.arguments {
                fmt.printf(
                    "{}{}",
                    op2.token.text,
                    index < len(variant.arguments)-1 ? " " : "",
                )
            }
        }

        if len(variant.results) > 0 {
            fmt.print(" --- ")
            for op2, index in variant.results {
                fmt.printf(
                    "{}{}",
                    op2.token.text,
                    index < len(variant.results)-1 ? " " : "",
                )
            }
        }
        fmt.println("):")

        for op2 in variant.body {
            print_op_debug(op2, level + 1)
        }
        print_prefix(level)
        fmt.printfln("; \e[1m{}\e[0m\n", variant.name.text)

    case Op_Return:
        print_op_name("RETURN")
        fmt.println()
    }
}

