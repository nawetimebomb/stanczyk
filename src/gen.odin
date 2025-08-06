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
}

start_generator :: proc() -> Generator {
    return Generator{
        cheaders      = strings.builder_make_len_cap(0, 4  ),
        stanczyk_defs = strings.builder_make_len_cap(0, 32 ),
        stanczyk_code = strings.builder_make_len_cap(0, 128),
        user_defs     = strings.builder_make_len_cap(0, 32 ),
        user_code     = strings.builder_make_len_cap(0, 128),
    }
}

write :: proc(s: ^strings.Builder, str: string) {
    fmt.sbprint(s, str)
}

writeln :: proc(s: ^strings.Builder, str: string) {
    fmt.sbprint(s, str)
    write(s, "\n")
}

writeln2 :: proc(s: ^strings.Builder, str1: string, str2: string) {
    write(s, str1)
    write(s, "\n")
    write(s, str2)
    write(s, "\n")
}

writef :: proc(s: ^strings.Builder, format: string, args: ..any) {
    fmt.sbprintf(s, format, ..args)
}

writefln :: proc(s: ^strings.Builder, format: string, args: ..any) {
    writef(s, format, ..args)
    write(s, "\n")
}

gen_initial_cheaders :: proc(s: ^strings.Builder) {
    writeln(s, "#include <stdio.h>")
    writeln(s, "#include <stdint.h>")
    writeln2(s, "#include <stddef.h>", "")
}

gen_stanczyk_defines :: proc(s: ^strings.Builder) {
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
#define SKC_STATIC static

SKC_STATIC void _write_buffer_to_fd(int fd, byteptr buf, int len);
SKC_STATIC void _writeln_to_fd(int fd, string s);
SKC_STATIC void print(string s);
SKC_STATIC void println(string s);

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

gen_stanczyk_code :: proc(s: ^strings.Builder) {
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

SKC_STATIC void print(string s) {
    _write_buffer_to_fd(1, s.str, s.len);
}

SKC_STATIC void println(string s) {
    _writeln_to_fd(1, s);
}`)
}

gen_identifier :: proc(gen: ^Generator, node: ^Ast) {
    variant := node.variant.(Ast_Identifier)
    writef(&gen.user_code, variant.foreign_name)
}

gen_literal :: proc(gen: ^Generator, node: ^Ast) {
    switch v in node.type.variant {
    case Type_Any:     unimplemented()
    case Type_Array:   unimplemented()
    case Type_Basic:
        switch v.kind {
        case .Invalid:
            unimplemented()
        case .Bool:
            write(&gen.user_code, value_to_string(node.value))
        case .Byte:
            writef(&gen.user_code, "({})'{}'", type_to_foreign_type(node.type), value_to_string(node.value))
        case .Float:
            writef(&gen.user_code, "({}){}", type_to_foreign_type(node.type), value_to_string(node.value))
        case .Int:
            writef(&gen.user_code, "({}){}", type_to_foreign_type(node.type), value_to_string(node.value))
        case .String:
            writef(&gen.user_code, `_S("{}")`, value_to_string(node.value))
        }
    case Type_Nil:     write(&gen.user_code, "NULL")
    case Type_Pointer: unimplemented()
    }
//    writef(&gen.user_code, "_S(\"{}\")", value_to_string(node.value))
}

gen_proc_call :: proc(gen: ^Generator, node: ^Ast) {
    variant := node.variant.(Ast_Proc_Call)

    writef(&gen.user_code, "\t{}(", variant.foreign_name)
    for child, index in variant.params {
        gen_program(gen, child)

        if index != len(variant.params) - 1 {
            write(&gen.user_code, ",")
        }
    }
    writeln(&gen.user_code, ");")
}

gen_proc_decl :: proc(gen: ^Generator, node: ^Ast) {
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

    writef(&gen.user_defs, "void {}(", variant.foreign_name)
    gen_parameters(&gen.user_defs, variant.params)
    writeln(&gen.user_defs, ");")

    writef(&gen.user_code, "void {}(", variant.foreign_name)
    gen_parameters(&gen.user_code, variant.params)
    writeln(&gen.user_code, ") {")
    for child in variant.body {
        gen_program(gen, child)
    }
    writeln2(&gen.user_code, "}", "")
}

gen_program :: proc(gen: ^Generator, node: ^Ast) {
    switch v in node.variant {
    case Ast_Identifier: gen_identifier(gen, node)
    case Ast_Literal:    gen_literal   (gen, node)
    case Ast_Proc_Call:  gen_proc_call (gen, node)
    case Ast_Proc_Decl:  gen_proc_decl (gen, node)
    case Ast_Return:
    }
}

generate :: proc() {
    gen := start_generator()

    gen_initial_cheaders(&gen.cheaders)
    gen_stanczyk_defines(&gen.stanczyk_defs)
    gen_stanczyk_code(&gen.stanczyk_code)

    writeln(&gen.user_defs, "// User definitions start here")
    writeln(&gen.user_code, "// User code start here")

    for ast in parser.program {
        gen_program(&gen, ast)
    }

    write_to_file(&gen)
}

write_to_file :: proc(gen: ^Generator) {
    result := strings.builder_make()
    defer strings.builder_destroy(&result)

    writeln(&result, strings.to_string(gen.cheaders))
    writeln(&result, strings.to_string(gen.stanczyk_defs))
    writeln(&result, strings.to_string(gen.stanczyk_code))
    writeln(&result, strings.to_string(gen.user_defs))
    writeln(&result, strings.to_string(gen.user_code))

    writeln(&result, `int main(int argc, const char *argv) {
    stanczyk__main();
    return 0;
}`)

    os.write_entire_file(fmt.tprintf("{}.c", output_filename), result.buf[:])
}
