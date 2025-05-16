package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

Codegen :: struct {
    source: strings.Builder,
    depth:  int,
    indent: int,
}

codegen: Codegen

codegen_indent :: proc() {
    indent := "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
    fmt.sbprint(&codegen.source, indent[:clamp(codegen.indent, 0, len(indent) - 1)])
}

codegen_scope_begin :: proc(visible := true, msg := "") {
    codegen.depth += 1
    if visible {
        codegen.indent += 1
        codegen_printf(" {{{}\n", msg)
    }
}

codegen_scope_end :: proc(visible := true) {
    codegen.depth -= 1
    if visible {
        codegen.indent -= 1
        codegen_indent()
        codegen_print("}")
    }
}

codegen_print :: proc(args: ..any) {
    fmt.sbprint(&codegen.source, args = args)
}

codegen_printf :: proc(format: string, args: ..any) {
    fmt.sbprintf(&codegen.source, fmt = format, args = args)
}

main :: proc() {
    codegen.source = strings.builder_make()

    codegen_print("#include \"stanczyk.h\"\n")
    codegen_print("\n")
    codegen_print("int main()")
    codegen_scope_begin()
    codegen_indent()
    codegen_printf("string_println((String){{ .data = \"{0}\", .len = {1} });\n", "Hello, Stanczyk", 16)
    codegen_scope_end()

    os.write_entire_file("result.c", codegen.source.buf[:])
}
