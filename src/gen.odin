#+private file
package main

import "core:fmt"
import "core:os"
import "core:reflect"
import "core:slice"
import "core:strings"

BACKEND_BUILTIN_C :: #load("include/builtin.c")

INLINE_PROC_DEF :: "skc_inline"
STATIC_PROC_DEF :: "skc_program"

Gen :: struct {
    source:    strings.Builder,
    depth:     int,
    indent:    int,
    sim_stack: [dynamic]Type,
}

get_c_function_name :: proc(p: Procedure) -> string {
    fn_definition := p.is_inline ? INLINE_PROC_DEF : STATIC_PROC_DEF
    return fmt.tprintf("{} void stanczyk__ip{}", fn_definition, p.ip)
}

gen_print :: proc(g: ^Gen, args: ..any) {
    fmt.sbprint(&g.source, args = args)
}

gen_printf :: proc(g: ^Gen, format: string, args: ..any) {
    fmt.sbprintf(&g.source, fmt = format, args = args)
}

gen_indent :: proc(g: ^Gen) {
    indent := "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
    fmt.sbprint(&g.source, indent[:clamp(g.indent, 0, len(indent) - 1)])
}

gen_scope_begin :: proc(g: ^Gen, visible := true, msg := "") {
    g.depth += 1
    if visible {
        g.indent += 1
        gen_printf(g, " {{{}\n", msg)
    }
}

gen_scope_end :: proc(g: ^Gen, visible := true) {
    g.depth -= 1
    if visible {
        g.indent -= 1
        gen_indent(g)
        gen_print(g, "}\n")
    }
}

gen_main_proc :: proc(g: ^Gen) {
    skc_main_proc_ip := 0

    for p in program.procs {
        if p.name == "main" {
            skc_main_proc_ip = p.ip
            break
        }
    }

    gen_printf(g, "skc_program void stanczyk__main()")
    gen_scope_begin(g)
    gen_indent(g)
    gen_printf(g, "stanczyk__ip{}();\n", skc_main_proc_ip)
    gen_scope_end(g)
}

gen_headers :: proc(g: ^Gen) {
    for p in program.procs {
        gen_printf(g, "{}();\n", get_c_function_name(p))
    }

    gen_print(g, "\n")
}

gen_procs :: proc(g: ^Gen) {
    for p in program.procs {
        gen_printf(g, "\n{}()", get_c_function_name(p))
        gen_scope_begin(g)

        for op in p.ops {
            gen_indent(g)

            switch v in op.kind {
            case Op_Push_Bool:
                gen_printf(g, "bool_push({});\n", v.value ? "bool_true" : "bool_false")
            case Op_Push_Float:
                gen_printf(g, "float_push({});\n", v.value)
            case Op_Push_Integer:
                gen_printf(g, "int_push({});\n", v.value)
            case Op_Push_String:
                gen_printf(g, "string_push((String){{ .data = \"{}\", .len = {} });\n", v.value, len(v.value))

            case Op_Arithmetic:
                operands_type := reflect.enum_name_from_value(v.operands) or_break
                operation := reflect.enum_name_from_value(v.operation) or_break
                gen_printf(g, "{}_{}();\n", operands_type, operation)

            case Op_Drop:
                gen_print(g, "stack_pop();\n")
            case Op_Dup:
                gen_print(g, "stack_dup();\n")
            case Op_Print:
                type_str := type_to_string(Type{ variant = v.kind})
                print_fn := v.newline ? "println" : "print"
                gen_printf(g, "{0}_{1}({2}_pop());\n", type_str, print_fn, type_str)
            }
        }

        gen_scope_end(g)
    }
}

@(private)
gen_program :: proc() {
    gen: Gen
    gen.source = strings.builder_make()

    gen_printf(&gen, "{}\n", string(BACKEND_BUILTIN_C))
    gen_headers(&gen)
    gen_main_proc(&gen)
    gen_procs(&gen)

    fmt.println(string(gen.source.buf[:]))

    os.write_entire_file("generated.c", gen.source.buf[:])
}
