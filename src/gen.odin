package main

import "core:fmt"
import "core:os/os2"
import "core:slice"
import "core:strings"

Generator :: struct {
    head:          strings.Builder,
    multi:         strings.Builder,
    sk_code:       strings.Builder,
    code:          strings.Builder,
    defs:          strings.Builder,
    indent:        int,

    source:        ^strings.Builder,
    multi_results: [dynamic]string,
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

gen_multiresult_str :: proc(gen: ^Generator, params: []^Op_Code) -> string {
    result := strings.builder_make(context.temp_allocator)

    strings.write_string(&result, "multi_")

    for param, index in params {
        strings.write_string(&result, type_to_foreign_name(param.type))
        if index < len(params)-1 do strings.write_string(&result, "_")
    }

    index, found := slice.binary_search(gen.multi_results[:], strings.to_string(result))

    if !found {
        result_str := strings.to_string(result)

        append(&gen.multi_results, strings.clone(result_str))

        fmt.sbprintf(&gen.multi, "typedef struct {} {{\n", result_str)
        for param, index in params {
            fmt.sbprintf(&gen.multi, "\t{} {}{};\n", type_to_foreign_name(param.type), MULTI_RESULT_PREFIX, index)
        }
        fmt.sbprintf(&gen.multi, "} {};\n", result_str)

        return result_str
    }

    return gen.multi_results[index]
}

gen_register :: proc(gen: ^Generator, reg: ^Register) {
    gen_printf(gen, "{}%d", reg.prefix, reg.ip)
}

gen_result_type :: proc(gen: ^Generator, results: []^Op_Code) {
    if len(results) == 0 {
        gen_print(gen, "void")
    } else if len(results) == 1 {
        gen_printf(gen, "{}", type_to_foreign_name(results[0].type))
    } else {
        gen_printf(gen, "{}", gen_multiresult_str(gen, results))
    }
}

gen_proc_signature :: proc(gen: ^Generator, op: ^Op_Code) {
    variant := op.variant.(Op_Proc_Decl)
    gen_printf(gen, "SK_STATIC ")
    gen_result_type(gen, variant.results)
    gen_printf(gen, " {}(", variant.foreign_name)

    for child, index in variant.arguments {
        gen_printf(gen, "{} ", type_to_foreign_name(child.type))
        gen_register(gen, child.register)

        if index < len(variant.arguments)-1 {
            gen_print(gen, ", ")
        }
    }
    gen_print(gen, ")")
}

gen_op :: proc(gen: ^Generator, op: ^Op_Code) {
    switch variant in op.variant {
    case Op_Identifier:
        assert(false, "Compiler Bug: Identifier should have been evaluated in checker")

    case Op_Constant:
        gen_op_push_constant(gen, op)
    case Op_Plus:
        gen_op_plus(gen, op)
    case Op_Proc_Call:
        gen_op_proc_call(gen, op)
    case Op_Return:
        gen_op_return(gen, op)

    case Op_Proc_Decl: // skipped

    case Op_Drop: // skipped
    case Op_Type_Lit:    gen_op_type_lit   (gen, op)
    case Op_Binary_Expr: gen_op_binary_expr(gen, op)
    }
}

gen_op_push_constant :: proc(gen: ^Generator, op: ^Op_Code) {
    variant := op.variant.(Op_Constant)
    assert(op.register != nil)

    gen_register(gen, op.register)
    gen_printf(gen, " = {}", op.value)
}

gen_op_plus :: proc(gen: ^Generator, op: ^Op_Code) {
    assert(op.register != nil)
    variant := op.variant.(Op_Plus)

    gen_register(gen, op.register)
    gen_print(gen, " = ")
    gen_register(gen, variant.lhs)
    gen_print(gen, " + ")
    gen_register(gen, variant.rhs)
}

gen_op_proc_call :: proc(gen: ^Generator, op: ^Op_Code) {
    variant := op.variant.(Op_Proc_Call)

    if len(variant.results) == 1 {
        result := variant.results[0]
        gen_register(gen, result.register)
        gen_print(gen, " = ")
    } else if len(variant.results) > 1 {
        gen_printf(gen, "{} multi{} = ", gen_multiresult_str(gen, variant.results), op.ip)
    }

    gen_printf(gen, "{}(", variant.foreign_name)
    for arg, index in variant.arguments {
        gen_register(gen, arg.register)

        if index < len(variant.arguments)-1 {
            gen_print(gen, ", ")
        }
    }
    gen_print(gen, ")")

    if len(variant.results) > 1 {
        gen_print(gen, ";\n")
        for result, index in variant.results {
            gen_indent(gen)
            gen_register(gen, result.register)
            gen_printf(gen, " = multi{}.{}{}", op.ip, MULTI_RESULT_PREFIX, index)
            if index < len(variant.results)-1 {
                gen_print(gen, ";\n")
            }
        }
    }
}

gen_op_type_lit :: proc(gen: ^Generator, op: ^Op_Code) {

}

gen_op_binary_expr :: proc(gen: ^Generator, op: ^Op_Code) {
    assert(op.register != nil)
    variant := op.variant.(Op_Binary_Expr)

    gen_register(gen, op.register)
    gen_print(gen, " = ")
    gen_register(gen, variant.lhs)
    gen_printf(gen, " {} ", variant.op)
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
        gen_printf(gen, "{} ", type_to_foreign_name(key))

        for &reg, index in array {
            gen_register(gen, &reg)

            if index < len(array)-1 {
                gen_print(gen, ", ")
            }

            if (index + 1) % 10 == 0 {
                gen_print(gen, "\n")
                gen_indent(gen)
                gen_print(gen, "    ")
            }
        }

        gen_print(gen, ";\n")
    }

    for child in variant.body {
        #partial switch _ in child.variant {
        case Op_Proc_Decl, Op_Drop: // skipped
        case:
            gen_indent(gen)
            gen_op(gen, child)
            gen_print(gen, ";\n")
        }
    }

    gen_end_scope(gen)
}

gen_op_return :: proc(gen: ^Generator, op: ^Op_Code) {
    variant := op.variant.(Op_Return)

    gen_print(gen, "return")

    if len(variant.results) == 0 do return

    gen_print(gen, " ")

    if len(variant.results) == 1 {
        result := variant.results[0]

        gen_print(gen, "(")
        gen_result_type(gen, variant.results)
        gen_print(gen, ")")
        gen_register(gen, result.register)
    } else {
        gen_print(gen, "(")
        gen_result_type(gen, variant.results)
        gen_print(gen, ")")
        gen_print(gen, "{")
        for result, index in variant.results {
            gen_printf(gen, ".{}{}=", MULTI_RESULT_PREFIX, index)
            gen_register(gen, result.register)
            if index < len(variant.results)-1 {
                gen_print(gen, ", ")
            }
        }
        gen_print(gen, "}")
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

gen_bootstrap :: proc(gen: ^Generator) {
    gen.source = &gen.head
    gen_print(gen, "#include <stdio.h>\n")
    gen_print(gen, "#include <stdint.h>\n")
    gen_print(gen, "\n")

    gen_print(gen, "#define SK_EXPORT extern __declspec(dllexport)\n")
    gen_print(gen, "#define SK_INLINE static inline\n")
    gen_print(gen, "#define SK_STATIC static\n")
    gen_print(gen, "\n")

    gen_print(gen, "// Stanczyk Builtin Types\n")
    gen_print(gen, "typedef int64_t s64;\n")

    gen.source = &gen.multi
    gen_print(gen, "// Stanczyk Multireturn types\n")

    gen.source = &gen.sk_code
    gen_print(gen, "// Stanczyk Internal Procedures\n")
    gen_print(gen, "static void internal_print(s64 n);\n")
    gen_print(gen, "\n")
    gen_print(gen, "static void internal_print(s64 n)\n")
    gen_begin_scope(gen)
    gen_indent(gen)
    gen_print(gen, "printf(\"%lli\\n\", n);\n")
    gen_end_scope(gen)


    gen.source = &gen.defs
    gen_print(gen, "// User Definitions\n")

    gen.source = &gen.code
    gen_print(gen, "// User Code\n")

}

gen_program :: proc() {
    gen := new(Generator)
    gen.head    = strings.builder_make()
    gen.multi   = strings.builder_make()
    gen.sk_code = strings.builder_make()
    gen.defs    = strings.builder_make()
    gen.code    = strings.builder_make()

    gen_bootstrap(gen)

    for op in program_bytecode {
        gen_procs_recursive(gen, op)
    }

    write_file(gen)
}

write_file :: proc(gen: ^Generator) {
    result := strings.builder_make()
    strings.write_string(&result, strings.to_string(gen.head))
    strings.write_string(&result, "\n")
    strings.write_string(&result, strings.to_string(gen.multi))
    strings.write_string(&result, "\n")
    strings.write_string(&result, strings.to_string(gen.sk_code))
    strings.write_string(&result, "\n")
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

    error := os2.write_entire_file(fmt.tprintf("{}.c", output_filename), result.buf[:])
    if error != nil {
        fatalf(.Generator, "could not generate output file")
    }
}
