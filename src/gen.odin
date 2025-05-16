package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

Gen :: struct {
    source: strings.Builder,
    depth:  int,
    indent: int,
    type_stack: [dynamic]Type,
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

gen_op_push_string :: proc(g: ^Gen, op: Op_Push_String) {
    // Note: we want to get rid of the `"` characters.
    str_len := len(op.value) - 2

    gen_indent(g)
    gen_print(g, "push_string(")
    gen_printf(g, "(String){{ .data = {0}, .len = {1} }", op.value, str_len)
    gen_print(g, ");\n")
    append(&g.type_stack, Type.String)
}

gen_op_print :: proc(g: ^Gen, op: Op_Print) {
    // TODO: Error when stack is empty
    type := pop(&g.type_stack)
    func_name := op.newline ? "println" : "print"

    gen_indent(g)

    switch type {
    case .String: gen_printf(g, "{}_string(pop_string());\n", func_name)
    }
}

gen_proc :: proc(g: ^Gen, p: Procedure) {
    gen_printf(g, "void skc__{}_{}() ", p.name, p.ip)
    gen_scope_begin(g)

    for op in p.ops {
        switch v in op.kind {
        case Op_Push_Integer:
        case Op_Push_String: gen_op_push_string(g, v)
        case Op_Print:       gen_op_print(g, v)
        case Op_Repl_Exit:
        }
    }

    gen_scope_end(g)
}

gen_main_proc :: proc(g: ^Gen) {
    skc_main_proc_ip := 0

    for p in program.procs {
        if p.name == "main" {
            skc_main_proc_ip = p.ip
            break
        }
    }

    gen_printf(g, "void stanczyk__main() ")
    gen_scope_begin(g)
    gen_indent(g)
    gen_printf(g, "skc__main_{}()\n", skc_main_proc_ip)
    gen_scope_end(g)
}

gen_program :: proc() {
    gen: Gen
    gen.source = strings.builder_make()

    for p in program.procs {
        gen_proc(&gen, p)
    }

    gen_main_proc(&gen)

    fmt.println(string(gen.source.buf[:]))
}
