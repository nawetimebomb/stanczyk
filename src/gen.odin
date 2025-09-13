package main

import "core:fmt"
import "core:os/os2"
import "core:strings"

Generator :: struct {
    code:   strings.Builder,
    defs:   strings.Builder,
    indent: int,

    source: ^strings.Builder,
}

gen_indent :: proc(gen: ^Generator) {
    assert(gen.source != nil)
    ind := "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
    fmt.sbprint(gen.source, ind[:clamp(gen.indent, 0, len(ind) - 1)])
}

gen_print :: proc(gen: ^Generator, args: ..any) {
    assert(gen.source != nil)
    fmt.sbprint(gen.source, args = args)
}

gen_printf :: proc(gen: ^Generator, format: string, args: ..any) {
    assert(gen.source != nil)
    fmt.sbprintf(gen.source, fmt = format, args = args)
}

gen_begin_scope :: proc(gen: ^Generator, visible := true, message := "") {
    if visible {
        gen.indent += 1
        gen_printf(gen, "{{{}\n", message)
    }
}

gen_end_scope :: proc(gen: ^Generator, visible := true) {
    if visible {
        gen.indent -= 1
        gen_indent(gen)
        gen_print(gen, "}\n")
    }
}

gen_register :: proc(gen: ^Generator, reg: ^Register) {
    gen_printf(gen, "{}{}", reg.prefix, reg.ip)
}

gen_result_type :: proc(gen: ^Generator, results: []^Op_Code) {
    if len(results) == 0 {
        gen_print(gen, "void")
    } else if len(results) == 1 {
        gen_printf(gen, "{}", type_to_cname(results[0].type))
    } else {
        // TODO(nawe) register to multi results
        assert(false)
    }
}

gen_proc_signature :: proc(gen: ^Generator, op: ^Op_Code) {
    variant := op.variant.(Op_Proc_Decl)
    gen_printf(gen, "static ")
    gen_result_type(gen, variant.results)
    gen_printf(gen, " {}(", variant.cname)

    for child, index in variant.arguments {
        gen_printf(gen, "{} ", type_to_cname(child.type))
        gen_register(gen, child.register)

        if index < len(variant.arguments)-1 {
            gen_print(gen, ", ")
        }
    }
    gen_print(gen, ")")
}

gen_op :: proc(gen: ^Generator, op: ^Op_Code) {
    switch variant in op.variant {
    case Op_Proc_Decl:     // skipped
    case Op_Push_Constant: gen_op_push_constant(gen, op)

    case Op_Identifier:  gen_op_identifier (gen, op)
    case Op_Type_Lit:    gen_op_type_lit   (gen, op)
    case Op_Binary_Expr: gen_op_binary_expr(gen, op)
    case Op_Return:      gen_op_return     (gen, op)
    }
}

gen_op_push_constant :: proc(gen: ^Generator, op: ^Op_Code) {
    variant := op.variant.(Op_Push_Constant)
    assert(op.register != nil)

    gen_register(gen, op.register)
    gen_printf(gen, "={}", op.value)
}

gen_op_identifier :: proc(gen: ^Generator, op: ^Op_Code) {

}

gen_op_type_lit :: proc(gen: ^Generator, op: ^Op_Code) {

}

gen_op_binary_expr :: proc(gen: ^Generator, op: ^Op_Code) {
    assert(op.register != nil)
    variant := op.variant.(Op_Binary_Expr)

    gen_register(gen, op.register)
    gen_print(gen, "=")
    gen_register(gen, variant.lhs)
    gen_print(gen, variant.op)
    gen_register(gen, variant.rhs)
}

gen_op_proc_decl :: proc(gen: ^Generator, op: ^Op_Code) {
    variant := op.variant.(Op_Proc_Decl)

    gen.source = &gen.defs
    gen_proc_signature(gen, op)
    gen_printf(gen, ";\n")

    gen.source = &gen.code
    gen_proc_signature(gen, op)
    gen_printf(gen, "\n")

    gen_begin_scope(gen)

    for key, array in variant.registers {
        gen_indent(gen)
        gen_printf(gen, "{} ", type_to_cname(key))

        for &reg, index in array {
            gen_register(gen, &reg)

            if index < len(array)-1 {
                gen_print(gen, ", ")
            } else {
                gen_print(gen, ";\n")
            }
        }
    }

    for child in variant.body {
        gen_indent(gen)
        gen_op(gen, child)
        gen_print(gen, ";\n")
    }

    gen_end_scope(gen)
}

gen_op_return :: proc(gen: ^Generator, op: ^Op_Code) {
    variant := op.variant.(Op_Return)
    if len(variant.results) == 0 do return

    gen_print(gen, "return ")

    if len(variant.results) == 1 {
        result := variant.results[0]

        gen_result_type(gen, variant.results)
        gen_print(gen, "(")
        gen_register(gen, result.register)
        gen_print(gen, ")")
    } else {
        assert(false)
    }
}

gen_procs_recursive :: proc(gen: ^Generator, op: ^Op_Code) {
    if proc_op, is_proc_decl := op.variant.(Op_Proc_Decl); is_proc_decl {
        gen_op_proc_decl(gen, op)

        for child in proc_op.body {
            gen_procs_recursive(gen, child)
        }
    }
}

gen_program :: proc() {
    gen := new(Generator)
    gen.code = strings.builder_make()

    for op in program_bytecode {
        gen_procs_recursive(gen, op)
    }

    write_file(gen)
}

write_file :: proc(gen: ^Generator) {
    result := strings.builder_make()
    strings.write_string(&result, strings.to_string(gen.defs))
    strings.write_string(&result, "\n")
    strings.write_string(&result, strings.to_string(gen.code))

    gen.source = &result
    gen_print(gen, "int main(int argc, const char *argv)")
    gen_begin_scope(gen)
    gen_indent(gen)
    gen_print(gen, "stanczyk__main();\n")
    gen_indent(gen)
    gen_print(gen, "return 0;\n")
    gen_end_scope(gen)

    error := os2.write_entire_file(output_filename, result.buf[:])
    if error != nil {
        fatalf(.Generator, "could not generate output file")
    }
}
