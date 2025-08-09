package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

GENERIC_STRUCT_FIELD_NAME :: "arg"

Generator :: struct {
    cheaders: strings.Builder,

    // The Stanczyk standards and internals
    stanczyk_defs:    strings.Builder,
    stanczyk_code:    strings.Builder,
    stanczyk_results: strings.Builder,

    // The user defined content
    user_code:    strings.Builder,
    user_defs:    strings.Builder,
    user_globals: strings.Builder,

    // A builder for when a procedure is created, allows to declare stack needed
    // variables at the top of the procedure.
    top_proc_buffer: ^strings.Builder,

    indent_level: int,
}

init_generator :: proc(gen: ^Generator) {
    gen.cheaders      = strings.builder_make_len_cap(0, 4  )
    gen.stanczyk_defs = strings.builder_make_len_cap(0, 32 )
    gen.stanczyk_code = strings.builder_make_len_cap(0, 128)
    gen.user_defs     = strings.builder_make_len_cap(0, 32 )
    gen.user_code     = strings.builder_make_len_cap(0, 128)
    gen.indent_level  = 0
}

write_indent :: proc(s: ^strings.Builder) {
    for x := len(s.buf) - 1; x > 0; x -= 1 {
        if s.buf[x] != '\t' {
            break
        }

        pop(&s.buf)
    }

    indents := "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
    fmt.sbprint(s, indents[:clamp(gen.indent_level, 0, len(indents) - 1)])
}

write :: proc(s: ^strings.Builder, str: string) {
    fmt.sbprint(s, str)
}

writeln :: proc(s: ^strings.Builder, str: string) {
    fmt.sbprint(s, str)
    write(s, "\n")
    write_indent(s)
}

writeln2 :: proc(s: ^strings.Builder, str1: string, str2: string) {
    write(s, str1)
    write(s, "\n")
    write_indent(s)
    write(s, str2)
    write(s, "\n")
    write_indent(s)
}

writef :: proc(s: ^strings.Builder, format: string, args: ..any) {
    fmt.sbprintf(s, format, ..args)
}

writefln :: proc(s: ^strings.Builder, format: string, args: ..any) {
    writef(s, format, ..args)
    write(s, "\n")
    write_indent(s)
}

gen_open_codeblock :: proc(s: ^strings.Builder) {
    gen.indent_level += 1
    writeln(s, " {")
}

gen_close_codeblock :: proc(s: ^strings.Builder, with_semicolon := false) {
    close_str := with_semicolon ? "};" : "}"
    gen.indent_level -= 1
    write_indent(s)
    writeln2(s, close_str, "")
}

gen_initial_cheaders :: proc() {
    s := &gen.cheaders

    writeln(s, "#include <stdio.h>")
    writeln(s, "#include <stdint.h>")
    writeln(s, "#include <stdbool.h>")
    writeln(s, "#include <stdlib.h>")
    writeln2(s, "#include <stddef.h>", "")
}

gen_stanczyk_defines :: proc() {
    s := &gen.stanczyk_defs

    writeln(s, "// Stanczyk Builtins")
    writeln(s, `typedef int64_t i64;
typedef int32_t i32;
typedef int16_t i16;
typedef int8_t i8;
typedef uint64_t u64;
typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t u8;
typedef u8 byte;
typedef u32 rune;
typedef size_t usize;
typedef ptrdiff_t isize;
typedef float f32;
typedef double f64;
typedef unsigned char* byteptr;
typedef void* voidptr;
typedef char* charptr;
typedef charptr string;

#define SKC_EXPORT extern __declspec(dllexport)
#define SKC_INLINE static inline
#define SKC_STATIC static

// Stanczyk Structs`)
}

gen_stanczyk_code :: proc() {
    s := &gen.stanczyk_code

    writeln(s, "// Stanczyk internal procedures")
}

gen_multiresult_str :: proc(params: []^Ast) -> string {
    result_str := strings.builder_make(context.temp_allocator)

    write(&result_str, "multi_")

    for param, index in params {
        write(&result_str, type_to_foreign_type(param.type))

        if index < len(params) - 1 {
            write(&result_str, "_")
        }
    }

    for el in generated_multi_results {
        if el == strings.to_string(result_str) {
            return el
        }
    }

    result := strings.clone(strings.to_string(result_str))
    append(&generated_multi_results, result)

    writefln(&gen.stanczyk_defs, "typedef struct {0} {0};", result)

    writef(&gen.stanczyk_results, "struct {}", result)
    gen_open_codeblock(&gen.stanczyk_results)

    for param, index in params {
        writefln(&gen.stanczyk_results, "{} {}{};",
                 type_to_foreign_type(param.type), GENERIC_STRUCT_FIELD_NAME, index)
    }

    gen_close_codeblock(&gen.stanczyk_results, true)

    return result
}

gen_assign :: proc(node: ^Ast, s: ^strings.Builder) {
    variant := node.variant.(Ast_Assign)

    gen_identifier(variant.assignee, s)
    write(s, " = ")
    gen_program(variant.value, s)
    writeln(s, ";")
}

gen_binary :: proc(node: ^Ast, s: ^strings.Builder) {
    variant := node.variant.(Ast_Binary)

    // NOTE(nawe) Maybe needed, in case we want to clean up the code generation
    // to not record the variable name when the stack is not handling this, but
    // instead is set in another variable. See tests/variables.sk:
    // var first-var 13 ;
    // var second-var first-var 2 + ;
    if variant.name != nil {
        if gen.top_proc_buffer != nil {
            writef(gen.top_proc_buffer, "{} ", type_to_foreign_type(node.type))
            gen_program(variant.name, gen.top_proc_buffer)
            writeln(gen.top_proc_buffer, ";")
        }

        gen_program(variant.name, s)
        write(s, " = ")
    }

    gen_program(variant.left, s)
    writef(s, " {} ", variant.operator)
    gen_program(variant.right, s)
    writeln(s, ";")
}

gen_identifier :: proc(node: ^Ast, s: ^strings.Builder) {
    variant := node.variant.(Ast_Identifier)
    writef(s, variant.foreign_name)
}

gen_if :: proc(node: ^Ast) {
    variant := node.variant.(Ast_If)
    s := &gen.user_code

    writeln(s, "")
    write(s, "if (")
    gen_program(variant.condition, s)
    write(s, ")")
    gen_open_codeblock(s)

    for child in variant.if_body {
        gen_program(child, s)
    }

    gen_close_codeblock(s)

    if len(variant.else_body) > 0 {
        write(s, "else")
        gen_open_codeblock(s)

        for child in variant.else_body {
            gen_program(child, s)
        }

        gen_close_codeblock(s)
    }
}

gen_literal :: proc(node: ^Ast, s: ^strings.Builder) {
    switch v in node.type.variant {
    case Type_Any:
        unimplemented()
    case Type_Array:
        unimplemented()
    case Type_Basic:
        switch v.kind {
        case .Invalid:
            unimplemented()
        case .Bool:
            write(s, value_to_string(node.value))
        case .Byte:
            writef(s, "({})'{}'", type_to_foreign_type(node.type), value_to_string(node.value))
        case .Cstring:
            writef(s, `"{}"`, value_to_string(node.value))
        case .String:
            writef(s, `"{}"`, value_to_string(node.value))

        case .Float, .Int, .Uint:
            writef(s, "({}){}", type_to_foreign_type(node.type), value_to_string(node.value))
        }
    case Type_Nil:
        write(s, "NULL")
    case Type_Pointer: unimplemented()
    }
}

gen_proc_call :: proc(node: ^Ast, s: ^strings.Builder) {
    variant := node.variant.(Ast_Proc_Call)

    writef(s, "{}(", variant.foreign_name)

    for child, index in variant.params {
        gen_program(child, s)

        if index != len(variant.params) - 1 {
            write(s, ", ")
        }
    }

    writeln(s, ");")
}

gen_proc_decl :: proc(node: ^Ast) {
    gen_parameters :: proc(s: ^strings.Builder, params: []^Ast) {
        for param, index in params {
            id, ok := param.variant.(Ast_Identifier)
            assert(ok)
            writef(s, "{} {}", type_to_foreign_type(param.type), id.foreign_name)

            if index != len(params) - 1 {
                write(s, ", ")
            }
        }
    }

    result_type_str := "void"
    variant := node.variant.(Ast_Proc_Decl)
    internal_builder := strings.builder_make(context.temp_allocator)
    gen.top_proc_buffer = &internal_builder

    if len(variant.results) == 1 {
        result := variant.results[0]
        result_type_str = type_to_foreign_type(result.type)
    } else if len(variant.results) > 1 {
        result_type_str = gen_multiresult_str(variant.results)
    }

    writef(&gen.user_defs, "SKC_STATIC {} {}(", result_type_str, variant.foreign_name)
    gen_parameters(&gen.user_defs, variant.params)
    writeln(&gen.user_defs, ");")

    writef(&gen.user_code, "SKC_STATIC {} {}(", result_type_str, variant.foreign_name)
    gen_parameters(&gen.user_code, variant.params)
    write(&gen.user_code, ")")
    gen_open_codeblock(&gen.user_code)

    top_of_proc_pos := len(gen.user_code.buf)

    for child in variant.body {
        gen_program(child, &gen.user_code)
    }

    if len(internal_builder.buf) > 0 {
        writeln(&internal_builder, "")
        inject_at(&gen.user_code.buf, top_of_proc_pos, strings.to_string(internal_builder))
    }

    gen_close_codeblock(&gen.user_code)

    strings.builder_destroy(&internal_builder)
}

gen_result_decl :: proc(node: ^Ast, s: ^strings.Builder) {
    variant := node.variant.(Ast_Result_Decl)
    result_str: string

    if len(variant.types) == 1 {
        result_str = type_to_foreign_type(variant.types[0].type)
    } else {
        result_str = gen_multiresult_str(variant.types)
    }

    writef(s, "{} ", result_str)
    gen_identifier(variant.name, s)
    write(s, " = ")
    gen_program(variant.value, s)
}

gen_return :: proc(node: ^Ast) {
    variant := node.variant.(Ast_Return)

    if len(variant.params) == 0 {
        return
    }

    if len(variant.params) == 1 {
        write(&gen.user_code, "return ")
        gen_program(variant.params[0], &gen.user_code)
        writeln(&gen.user_code, ";")
    } else {
        result_str := gen_multiresult_str(variant.params)

        write(&gen.user_code, "return ")
        writef(&gen.user_code, "({}){{", result_str)

        for param, index in variant.params {
            writef(&gen.user_code, ".{}{}=", GENERIC_STRUCT_FIELD_NAME, index)
            gen_program(param, &gen.user_code)

            if index < len(variant.params) - 1 {
                write(&gen.user_code, ", ")
            }
        }

        writeln(&gen.user_code, "};")
    }
}

gen_variable_decl :: proc(node: ^Ast) {
    variant := node.variant.(Ast_Variable_Decl)
    name := variant.name
    value := variant.value
    _, add_semicolon := value.variant.(Ast_Literal)
    s := &gen.user_code

    if variant.is_global {
        s = &gen.user_globals
    }

    writef(s, "{} ", type_to_foreign_type(value.type))
    gen_identifier(name, s)
    write(s, " = ")
    gen_program(value, s)

    if add_semicolon {
        writeln(s, ";")
    }
}

gen_program :: proc(node: ^Ast, s: ^strings.Builder) {
    switch v in node.variant {
    case Ast_Assign:        gen_assign       (node, s)
    case Ast_Binary:        gen_binary       (node, s)
    case Ast_Identifier:    gen_identifier   (node, s)
    case Ast_If:            gen_if           (node)
    case Ast_Literal:       gen_literal      (node, s)
    case Ast_Proc_Call:     gen_proc_call    (node, s)
    case Ast_Proc_Decl:     gen_proc_decl    (node)
    case Ast_Result_Decl:   gen_result_decl  (node, s)
    case Ast_Return:        gen_return       (node)
    case Ast_Variable_Decl: gen_variable_decl(node)
    }
}

gen: Generator
generated_multi_results: [dynamic]string

generate :: proc() {
    init_generator(&gen)

    gen_initial_cheaders()
    gen_stanczyk_defines()
    gen_stanczyk_code()

    writeln(&gen.user_code, "// User code start here")
    writeln(&gen.user_defs, "// User definitions start here")
    writeln(&gen.user_globals, "// User globals start here")

    for ast in parser.program {
        gen_program(ast, &gen.user_code)
    }

    write_to_file()
}

write_to_file :: proc() {
    result := strings.builder_make()
    defer strings.builder_destroy(&result)

    writeln(&result, strings.to_string(gen.cheaders))
    writeln(&result, strings.to_string(gen.stanczyk_defs))
    writeln(&result, strings.to_string(gen.stanczyk_code))
    writeln(&result, strings.to_string(gen.stanczyk_results))
    writeln(&result, strings.to_string(gen.user_defs))
    writeln(&result, strings.to_string(gen.user_globals))
    write(&result, strings.to_string(gen.user_code))

    writeln(&result, `int main(int argc, const char *argv) {
    stanczyk__main();
    return 0;
}`)

    os.write_entire_file(fmt.tprintf("{}.c", output_filename), result.buf[:])
}
