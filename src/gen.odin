#+private file
package main

import "core:fmt"
import "core:os"
import "core:reflect"
import "core:slice"
import "core:strings"

BACKEND_BUILTIN_C :: #load("include/builtin.c")

INLINE_PROC_DEF :: "SK_INLINE"
STATIC_PROC_DEF :: "SK_PROGRAM"

Gen :: struct {
    definitions: strings.Builder,
    headers:     strings.Builder,
    source:      strings.Builder,
    indent:      int,
}

g: Gen

write :: proc(s: ^strings.Builder, args: ..any) {
    fmt.sbprint(s, args = args)
}

writef :: proc(s: ^strings.Builder, format: string, args: ..any) {
    fmt.sbprintf(s, fmt = format, args = args)
}

writeln :: proc(s: ^strings.Builder, args: ..any) {
    write(s, args = args)
    write(s, "\n")
}

writefln :: proc(s: ^strings.Builder, format: string, args: ..any) {
    fmt.sbprintf(s, fmt = format, args = args)
    write(s, "\n")
}

write_indent :: proc(s: ^strings.Builder) {
    if g.indent > 0 {
        indent_str := "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
        write(s, indent_str[:clamp(g.indent, 0, len(indent_str) - 1)])
    }
}

indent_forward :: proc(s: ^strings.Builder, should_write := true) {
    g.indent += 1
    if should_write { write_indent(s) }
}

indent_backward :: proc(s: ^strings.Builder) {
    g.indent = max(g.indent - 1, 0)
    write_indent(s)
}

@(private)
gen_program :: proc() {
    g = Gen{
        definitions = strings.builder_make(),
        headers     = strings.builder_make(),
        source      = strings.builder_make(),
    }

    writeln(&g.headers, string(BACKEND_BUILTIN_C))

    for p in program.procs {
        if p.name == "main" {
            writefln(&g.source, "{} void main__stanczyk() {{", STATIC_PROC_DEF)
        } else {
            proc_prefix := p.is_inline ? INLINE_PROC_DEF : STATIC_PROC_DEF
            writefln(&g.definitions, "{0} void {1}__{2}();", proc_prefix, p.name, p.ip)
            writefln(&g.source, "{0} void {1}__{2}() {{", proc_prefix, p.name, p.ip)
        }

        indent_forward(&g.source, false)

        for op in p.ops {
            write_indent(&g.source)

            switch v in op.kind {
            case Op_Push_Bool:
                writefln(&g.source, "bool_push({});", v.value)
            case Op_Push_Float:
                writefln(&g.source, "f64_push({});", v.value)
            case Op_Push_Integer:
                writefln(&g.source, "s64_push({});", v.value)
            case Op_Push_String:
                writefln(&g.source, "string_push(__STRLEN(\"{}\", {}));", v.value, len(v.value))

            case Op_Binary:
                if v.operation == .and {
                    writeln(&g.source, "log_and();")
                } else if v.operation == .or {
                    writeln(&g.source, "log_or();")
                } else {
                    operands_name := type_to_cname(v.operands)
                    operation := reflect.enum_name_from_value(v.operation) or_break
                    writefln(&g.source, "{0}_{1}();", operands_name, operation)
                }
            case Op_Cast:
                writefln(&g.source, "{0}_to_{1}();", type_to_cname(v.from), type_to_cname(v.to))
            case Op_Drop:
                writeln(&g.source, "stack_pop();")
            case Op_Dup:
                writeln(&g.source, "stack_dup();")
            case Op_Print:
                operand_name := type_to_cname(v.operand)
                printfn := v.newline ? "println" : "print"
                writefln(&g.source, "{0}_{1}();", operand_name, printfn)
            case Op_Swap:
                writeln(&g.source, "stack_swap();")
            }
        }

        indent_backward(&g.source)
        writeln(&g.source, "}")
    }

    // Write the generated file
    result := strings.builder_make()
    writeln(&result, string(g.headers.buf[:]))
    writeln(&result, string(g.definitions.buf[:]))
    writeln(&result, string(g.source.buf[:]))
    os.write_entire_file(GENERATED_FILE_NAME, result.buf[:])
}
