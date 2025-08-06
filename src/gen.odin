package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

Generator :: struct {
    cheaders: strings.Builder,

    // The Stanczyk standards and internal procedures
    stanczyk_defs: strings.Builder,
    stanczyk_code: strings.Builder,

    // The user defined content
    user_defs: strings.Builder,
    user_code: strings.Builder,

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
}

gen_open_codeblock :: proc(s: ^strings.Builder) {
    gen.indent_level += 1
    writeln(s, " {")
}

gen_close_codeblock :: proc(s: ^strings.Builder) {
    gen.indent_level -= 1
    write_indent(s)
    writeln2(s, "}", "")
}

gen_initial_cheaders :: proc() {
    s := &gen.cheaders

    writeln(s, "#include <stdio.h>")
    writeln(s, "#include <stdint.h>")
    writeln(s, "#include <stdbool.h>")
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
typedef struct string string;

// #ifndef __cplusplus
//     #ifndef bool
//         typedef u8 bool;
//         #define true 1
//         #define false 0
//     #endif
// #endif

#define SKC_EXPORT extern __declspec(dllexport)
#define SKC_INLINE static inline
#define SKC_STATIC static

SKC_STATIC void _write_buffer_to_fd(int fd, byteptr buf, int len);
SKC_STATIC void _writeln_to_fd(int fd, string s);

SKC_STATIC void bool_print(bool it);
SKC_STATIC void bool_println(bool it);
SKC_STATIC void byte_print(byte it);
SKC_STATIC void byte_println(byte it);
SKC_STATIC void f64_print(f64 it);
SKC_STATIC void f64_println(f64 it);
SKC_STATIC void i64_print(i64 it);
SKC_STATIC void i64_println(i64 it);
SKC_STATIC void string_print(string it);
SKC_STATIC void string_println(string it);
SKC_STATIC void u64_print(u64 it);
SKC_STATIC void u64_println(u64 it);

SKC_INLINE string i64_to_string(i64 n);

// Stanczyk Macros
#define _SLIT0 (string){.str=(byteptr)(""), .len=0, .is_lit=1}
#define _S(s) ((string){.str=(byteptr)("" s), .len=(sizeof(s)-1), .is_lit=1})
#define _SLEN(s, n) ((string){.str=(byteptr)("" s), .len=n, .is_lit=1})

// Stanczyk Structs
struct string {
    byteptr str;
    int     len;
    int     is_lit;
};`)
}

gen_stanczyk_code :: proc() {
    s := &gen.stanczyk_code

    writeln(s, "// Stanczyk internal procedures")
    writeln(s, `SKC_STATIC void _writeln_to_fd(int fd, string s) {
    byte lf = (byte)'\n';
    _write_buffer_to_fd(fd, s.str, s.len);
    _write_buffer_to_fd(fd, &lf, 1);
}

SKC_STATIC void _write_buffer_to_fd(int fd, byteptr buf, int len) {
    if (len <= 0) {
        return;
    }
    byteptr ptr = buf;
    isize next_bytes = (isize)len;
    isize x = (isize)0;
    voidptr stream = (voidptr)stdout;
    if (fd == 2) {
        stream = (voidptr)stderr;
    }
    for (;;) {
        if (!(next_bytes) > 0) break;
        x = (isize)fwrite(ptr, 1, next_bytes, stream);
        ptr += x;
        next_bytes -= x;
    }
}

SKC_STATIC void bool_print(bool it) {
    printf("%s", it ? "true" : "false");
}

SKC_STATIC void bool_println(bool it) {
    printf("%s\n", it ? "true" : "false");
}

SKC_STATIC void byte_print(byte it) {
    printf("%c", it);
}

SKC_STATIC void byte_println(byte it) {
    printf("%c\n", it);
}

SKC_STATIC void f64_print(f64 it) {
    printf("%g", it);
}

SKC_STATIC void f64_println(f64 it) {
    printf("%g\n", it);
}

SKC_STATIC void i64_print(i64 it) {
    printf("%li", it);
}

SKC_STATIC void i64_println(i64 it) {
    printf("%li\n", it);
}

SKC_STATIC void string_print(string it) {
    _write_buffer_to_fd(1, it.str, it.len);
}

SKC_STATIC void string_println(string it) {
    _writeln_to_fd(1, it);
}

SKC_STATIC void u64_print(u64 it) {
    printf("%lu", it);
}

SKC_STATIC void u64_println(u64 it) {
    printf("%lu\n", it);
}`)
}

gen_identifier :: proc(node: ^Ast) {
    variant := node.variant.(Ast_Identifier)
    writef(&gen.user_code, variant.foreign_name)
}

gen_literal :: proc(node: ^Ast) {
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
            write(&gen.user_code, value_to_string(node.value))
        case .Byte:
            writef(&gen.user_code, "({})'{}'", type_to_foreign_type(node.type), value_to_string(node.value))
        case .String:
            writef(&gen.user_code, `_S("{}")`, value_to_string(node.value))

        case .Float, .Int, .Uint:
            writef(&gen.user_code, "({}){}", type_to_foreign_type(node.type), value_to_string(node.value))
        }
    case Type_Nil:
        write(&gen.user_code, "NULL")
    case Type_Pointer: unimplemented()
    }
}

gen_proc_call :: proc(node: ^Ast) {
    variant := node.variant.(Ast_Proc_Call)

    if variant.is_builtin {
        for child in variant.params {
            writef(&gen.user_code, "{}_", type_to_foreign_type(child.type))
        }
    }

    writef(&gen.user_code, "{}(", variant.foreign_name)

    for child, index in variant.params {
        gen_program(child)

        if index != len(variant.params) - 1 {
            write(&gen.user_code, ",")
        }
    }

    writeln(&gen.user_code, ");")
}

gen_proc_decl :: proc(node: ^Ast) {
    gen_parameters :: proc(s: ^strings.Builder, params: []^Ast) {
        for param, index in params {
            id, ok := param.variant.(Ast_Identifier)
            assert(ok)
            writef(s, "{} {}", type_to_foreign_type(param.type), id.foreign_name)

            if index != len(params) - 1 {
                write(s, ",")
            }
        }
    }

    variant := node.variant.(Ast_Proc_Decl)

    writef(&gen.user_defs, "SKC_STATIC void {}(", variant.foreign_name)
    gen_parameters(&gen.user_defs, variant.params)
    writeln(&gen.user_defs, ");")

    writef(&gen.user_code, "SKC_STATIC void {}(", variant.foreign_name)
    gen_parameters(&gen.user_code, variant.params)
    write(&gen.user_code, ")")
    gen_open_codeblock(&gen.user_code)
    for child in variant.body {
        gen_program(child)
    }
    gen_close_codeblock(&gen.user_code)
}

gen_program :: proc(node: ^Ast) {
    switch v in node.variant {
    case Ast_Identifier: gen_identifier(node)
    case Ast_Literal:    gen_literal   (node)
    case Ast_Proc_Call:  gen_proc_call (node)
    case Ast_Proc_Decl:  gen_proc_decl (node)
    case Ast_Return:
    }
}

gen: Generator

generate :: proc() {
    init_generator(&gen)

    gen_initial_cheaders()
    gen_stanczyk_defines()
    gen_stanczyk_code()

    writeln(&gen.user_defs, "// User definitions start here")
    writeln(&gen.user_code, "// User code start here")

    for ast in parser.program {
        gen_program(ast)
    }

    write_to_file()
}

write_to_file :: proc() {
    result := strings.builder_make()
    defer strings.builder_destroy(&result)

    writeln(&result, strings.to_string(gen.cheaders))
    writeln(&result, strings.to_string(gen.stanczyk_defs))
    writeln(&result, strings.to_string(gen.stanczyk_code))
    writeln(&result, strings.to_string(gen.user_defs))
    write(&result, strings.to_string(gen.user_code))

    writeln(&result, `int main(int argc, const char *argv) {
    stanczyk__main();
    return 0;
}`)

    os.write_entire_file(fmt.tprintf("{}.c", output_filename), result.buf[:])
}
