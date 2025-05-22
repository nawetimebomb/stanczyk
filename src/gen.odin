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

reindent :: proc(s: ^strings.Builder) {
    for s.buf[len(s.buf) - 1] == '\t' { pop(&s.buf) }
    write_indent(s)
}

indent_forward :: proc(s: ^strings.Builder, should_write := true) {
    g.indent += 1
    if should_write { write_indent(s) }
}

indent_backward :: proc(s: ^strings.Builder, should_write := true) {
    g.indent = max(g.indent - 1, 0)
    if should_write { write_indent(s) }
}

@(private)
gen_program :: proc() {
    g = Gen{
        definitions = strings.builder_make(),
        headers = strings.builder_make(),
        source = strings.builder_make(),
    }

    writeln(&g.headers, string(BACKEND_BUILTIN_C))

    for p in program.procs {
        if p.name == "main" {
            writefln(&g.source, "{} void main__stanczyk() {{", STATIC_PROC_DEF)
        } else {
            proc_prefix := p.is_inline ? INLINE_PROC_DEF : STATIC_PROC_DEF
            writefln(&g.definitions, "{} void proc{}(); // {} ({}:{})", proc_prefix, p.ip, p.name, p.loc.file, p.loc.offset)
            writefln(&g.source, "{} void proc{}() {{ // {} ({}:{})", proc_prefix, p.ip, p.name, p.loc.file, p.loc.offset)
        }

        indent_forward(&g.source, false)

        for op in p.ops {
            write_indent(&g.source)

            switch v in op.variant {
            case Op_Push_Bool:
                writefln(&g.source, "_builtin__push(SK_bool, (SKVALUE){{._bool = {}});", v.value)
            case Op_Push_Float:
                writefln(&g.source, "_builtin__push(SK_f{0}, (SKVALUE){{._f{0} = {1}});", word_size_in_bits, v.value)
            case Op_Push_Integer:
                writefln(&g.source, "_builtin__push(SK_s{0}, (SKVALUE){{._s{0} = {1}});", word_size_in_bits, v.value)
            case Op_Push_String:
                writefln(&g.source, "_builtin__push(SK_string, (SKVALUE){{._string = __STRLEN(\"{}\", {})});", v.value, len(v.value))
            case Op_Push_Quotation:
                writefln(&g.source, "_builtin__push(SK_quotation, (SKVALUE){{._quotation = \"{}\"});", v.value)

            case Op_Apply:
                writeln(&g.source, "_builtin__pop();")
            case Op_Binary:
                if v.operation == .and {
                    writeln(&g.source, "_builtin__and();")
                } else if v.operation == .or {
                    writeln(&g.source, "_builtin__or();")
                } else {
                    operation := reflect.enum_name_from_value(v.operation) or_break
                    writefln(&g.source, "_builtin__{}();", operation)
                }
            case Op_Call_Proc:
                writefln(&g.source, "proc{}(); // {}", v.ip, v.name)
            case Op_Cast:
                writefln(&g.source, "_builtin__cast({});", type_to_cenum(v.to))
            case Op_Describe_Type:
                type_name := type_to_ctype(v.type)
                writeln(&g.source, "_builtin__pop();")
                writefln(&g.source, "_builtin__push(SK_string, __STRLEN(\"{}\", {}));", type_name, len(type_name))
            case Op_Drop:
                writeln(&g.source, "_builtin__pop();")
            case Op_Dup:
                writeln(&g.source, "_builtin__dup();")
            case Op_If_Statement:
                switch v.operation {
                case .if_start:
                    writeln(&g.source, "if (bool_pop()) {")
                    indent_forward(&g.source, false)
                case .else_start:
                    indent_backward(&g.source, false)
                    reindent(&g.source)
                    writeln(&g.source, "} else {")
                    indent_forward(&g.source, false)
                case .elif_start:
                    // TODO: this doesn't work because it needs to go through if to push the boolean
                    indent_backward(&g.source, false)
                    reindent(&g.source)
                    writeln(&g.source, "} else if (bool_pop()) {")
                    indent_forward(&g.source, false)
                case .if_end:
                    indent_backward(&g.source, false)
                    reindent(&g.source)
                    writeln(&g.source, "}")
                }
            case Op_Print:
                writefln(&g.source, "_builtin__{}();", v.newline ? "println" : "print")
            case Op_Swap:
                writeln(&g.source, "_builtin__swap();")
            case Op_Unary:
                switch v.operation {
                case .minus_minus:
                    writefln(&g.source, "_builtin__push({}, (SKVALUE){{._{} = 1});", type_to_cenum(v.operand), type_to_ctype(v.operand))
                    writeln(&g.source, "_builtin__minus();")
                case .plus_plus:
                    writefln(&g.source, "_builtin__push({}, (SKVALUE){{._{} = 1});", type_to_cenum(v.operand), type_to_ctype(v.operand))
                    writeln(&g.source, "_builtin__plus();")
                }
            }
        }

        indent_backward(&g.source)
        writeln(&g.source, "}\n")
    }

    // Write the generated file
    result := strings.builder_make()
    writeln(&result, string(g.headers.buf[:]))
    writeln(&result, string(g.definitions.buf[:]))
    writeln(&result, string(g.source.buf[:]))
    os.write_entire_file(GENERATED_FILE_NAME, result.buf[:])
}
