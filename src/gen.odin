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

gen_ast :: proc(gen: ^Generator, ast: ^Ast) {
    switch variant in ast.variant {
    case Ast_Builtin:
        gen_printf(gen, "{}(", variant.cname)
        for arg, index in variant.arguments {
            gen_ast(gen, arg)
            if index < len(variant.arguments)-1 {
                gen_print(gen, ",")
            }
        }
        gen_print(gen, ")")

    case Ast_Basic_Literal: gen_basic_literal(gen, ast)
    case Ast_Binary:        gen_binary       (gen, ast)
    case Ast_Block:         gen_block        (gen, ast)
    case Ast_Proc_Decl:     gen_proc_decl    (gen, ast)
    }
}

gen_basic_literal :: proc(gen: ^Generator, ast: ^Ast) {
    value := ast.variant.(Ast_Basic_Literal)

    switch v in ast.value {
    case bool:    gen_printf(gen, "{}", v)
    case f64:     gen_printf(gen, "{}", v)
    case i64:     gen_printf(gen, "{}", v)
    case u64:     gen_printf(gen, "{}", v)
    case string:  gen_printf(gen, "{}", v)
    }
}

gen_binary :: proc(gen: ^Generator, ast: ^Ast) {
    value := ast.variant.(Ast_Binary)
}

gen_block :: proc(gen: ^Generator, ast: ^Ast) {
    value := ast.variant.(Ast_Block)

    for child in value.body {
        gen_indent(gen)
        gen_ast(gen, child)
        gen_print(gen, ";\n")
    }
}

gen_proc_decl :: proc(gen: ^Generator, ast: ^Ast) {
    value := ast.variant.(Ast_Proc_Decl)

    gen.source = &gen.defs
    gen_printf(gen, "static void {}();\n", value.cname)

    gen.source = &gen.code
    gen_printf(gen, "static void {}()\n", value.cname)
    gen_begin_scope(gen)
    gen_ast(gen, value.body)
    gen_end_scope(gen)
}

gen_program :: proc() {
    gen := new(Generator)
    gen.code = strings.builder_make()

    gen.source = &gen.code
    for ast in program_ast do gen_ast(gen, ast)

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
