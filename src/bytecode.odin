package main

import "core:fmt"

Op_Code :: struct {
    local_ip:  int,
    token:     Token,
    variant:   Op_Variant,
}

Op_Variant :: union {
    Op_Basic_Literal,
    Op_Identifier, // unsure what to do, depends on type checking
    Op_Type,

    Op_Binary,
    Op_Proc_Decl,

    Op_Return,
}

Op_Basic_Literal :: struct {
    type:  ^Type,
    value: Token,
}

Op_Identifier :: struct {
    value: Token,
}

Op_Type :: struct {
    value: ^Type,
}


Op_Binary :: struct {
    operator: Token,
}

Op_Proc_Decl :: struct {
    name:        Token,
    scope:       ^Scope,
    is_foreign:  bool,
    foreign_lib: Token,

    arguments:   [dynamic]Op_Code,
    results:     [dynamic]Op_Code,
    body:        [dynamic]Op_Code,
}

Op_Return :: struct {}

print_op_debug :: proc(op: Op_Code, level := 0) {
    print_op_name :: proc(s: string) {
        fmt.printf("%-15s", s)
    }

    print_prefix :: proc(level: int) {
        TABS := "\t\t\t\t\t\t\t\t\t\t\t\t\t"
        prefix := TABS[:level]
        fmt.printf("{}", prefix)
    }

    print_prefix(level)

    fmt.printf("(%5d) ", op.local_ip)
    switch variant in op.variant {
    case Op_Basic_Literal:
        print_op_name("BASIC_LITERAL")
        fmt.printfln("{} {}", type_to_string(variant.type), variant.value.text)
    case Op_Identifier:
        print_op_name("IDENTIFIER")
        fmt.println(variant.value.text)
    case Op_Type:
        print_op_name("TYPE")
        fmt.println(type_to_string(variant.value))

    case Op_Binary:
        print_op_name("BINARY")
        fmt.println(variant.operator.text)
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
    }

}
