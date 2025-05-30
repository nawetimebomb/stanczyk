package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

Generator :: struct {
    includes:        strings.Builder,
    defines:         strings.Builder,
    typedefs:        strings.Builder,
    structs:         strings.Builder,
    builtinglobals:  strings.Builder,
    builtinprocdefs: strings.Builder,
    builtinprocs:    strings.Builder,

    userdefs:     strings.Builder,
    userfuncs:    strings.Builder,

    global_ip:   uint,

    main_func_address: uint,
}

gen := Generator{}

write :: proc{write_to_builder, write_to_function}
writef :: proc{writef_to_builder, writef_to_function}
writeln :: proc{writeln_to_builder, writeln_to_function}
writefln :: proc{writefln_to_builder, writefln_to_function}

write_to_builder :: proc(s: ^strings.Builder, args: ..any) {
    fmt.sbprint(s, args = args)
}

write_to_function :: proc(f: ^Function, args: ..any) {
    fmt.sbprint(&f.code, args = args)
}

writef_to_builder :: proc(s: ^strings.Builder, format: string, args: ..any) {
    fmt.sbprintf(s, format, args = args)
}

writef_to_function :: proc(f: ^Function, format: string, args: ..any) {
    fmt.sbprintf(&f.code, format, args = args)
}

writeln_to_builder :: proc(s: ^strings.Builder, args: ..any) {
    write(s, args = args)
    write(s, "\n")
}

writeln_to_function :: proc(f: ^Function, args: ..any) {
    write(f, args = args)
    write(f, "\n")
    write_indent(f)
}

writefln_to_builder :: proc(s: ^strings.Builder, format: string, args: ..any) {
    writef(s, format, args = args)
    write(s, "\n")
}

writefln_to_function :: proc(f: ^Function, format: string, args: ..any) {
    writef(f, format, args = args)
    write(f, "\n")
    write_indent(f)
}

write_indent :: proc(f: ^Function) {
    if f.indent > 0 {
        indent_str := "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
        write(f, indent_str[:clamp(f.indent, 0, len(indent_str) - 1)])
    }
}

reindent :: proc(f: ^Function) {
    for f.code.buf[len(f.code.buf) - 1] == '\t' { pop(&f.code.buf) }
    write_indent(f)
}

indent_forward :: proc(f: ^Function, should_write := true) {
    f.indent += 1
    if should_write {
        reindent(f)
    }
}

indent_backward :: proc(f: ^Function, should_write := true) {
    f.indent = max(f.indent - 1, 0)
    if should_write {
        reindent(f)
    }
}

gen_global_address :: proc() -> (address: uint) {
    address = gen.global_ip
    gen.global_ip += 1
    return
}

gen_local_address :: proc(f: ^Function) -> (address: uint) {
    address = f.local_ip
    f.local_ip += 1
    return
}

gen_compilation_unit :: proc() {
    result := strings.builder_make(context.temp_allocator)
    writeln(&result, string(gen.includes.buf[:]))
    clear(&gen.includes.buf)
    writeln(&result, string(gen.typedefs.buf[:]))
    clear(&gen.typedefs.buf)
    writeln(&result, string(gen.defines.buf[:]))
    clear(&gen.defines.buf)
    writeln(&result, string(gen.structs.buf[:]))
    clear(&gen.structs.buf)
    writeln(&result, string(gen.builtinglobals.buf[:]))
    clear(&gen.builtinglobals.buf)
    writeln(&result, string(gen.builtinprocdefs.buf[:]))
    clear(&gen.builtinprocdefs.buf)
    writeln(&result, string(gen.builtinprocs.buf[:]))
    clear(&gen.builtinprocs.buf)
    writeln(&result, string(gen.userdefs.buf[:]))
    clear(&gen.userdefs.buf)
    writeln(&result, string(gen.userfuncs.buf[:]))
    clear(&gen.userfuncs.buf)
    writefln(&result, `int main(int ___argc, char** ___argv) {{
	g_main_argc = ___argc;
	g_main_argv = ___argv;
	skfuncip{}();
	return 0;
}`, gen.main_func_address)
    os.write_entire_file(fmt.tprintf("{}.c", output_filename), result.buf[:])
}

gen_bootstrap :: proc() {
    c_includes := []string{"assert.h", "stdint.h", "stdio.h", "stdlib.h", "string.h"}
    for inc in c_includes { writefln(&gen.includes, "#include <{}>", inc) }

    writeln(&gen.typedefs, `#if defined(__x86_64__) || defined(_M_AMD64) || defined(__aarch64__) || defined(__arm64__) || defined(_M_ARM64) || (defined(__riscv_xlen) && __riscv_xlen == 64) || defined(__s390x__) || (defined(__powerpc64__) && defined(__LITTLE_ENDIAN__)) || defined(__loongarch64)
	typedef int64_t skint;
	typedef uint64_t skuint;
	typedef double skfloat;
#else
	typedef int32_t skint;
	typedef uint32_t skuint;
	typedef float skfloat;
#endif

typedef int8_t skbool;
typedef uint8_t skbyte;
typedef unsigned char* skbyteptr;
typedef void* voidptr;
typedef struct skstring skstring;
typedef struct skquote skquote;
typedef struct skstack skstack;
typedef union skvalue skvalue;
typedef enum sktype sktype;`)

    writeln(&gen.defines, `#define SKSTACK_SIZE 128
#define SK_INLINE static inline
#define SK_PROGRAM static
#define SK_LOCAL static
#define SKFALSE (skbool) 0
#define SKTRUE (skbool) 1
#define __STRLIT(s,l) ((skstring){.data=(skbyteptr)("" s),.len=l,.literal=SKTRUE})`)

    writeln(&gen.structs, `struct skstring {
	skbyteptr data;
	skint len;
	skbool literal;
};

enum sktype {
	skbool_t, skfloat_t, skint_t, skstring_t, skuint_t,
};

union skvalue {
	skbool skbool;
	skbyte skbyte;
	skfloat skfloat;
	skint skint;
	skstring skstring;
    skuint skuint;
};

struct skstack {
	skint top;
	skvalue values[SKSTACK_SIZE];
};`)

    writeln(&gen.builtinglobals, `SK_PROGRAM skstack g_stack;
int g_main_argc = ((int)(0));
voidptr g_main_argv = ((voidptr)0);`)

    writeln(&gen.builtinprocdefs, `SK_PROGRAM void _push(skvalue v);
SK_PROGRAM skvalue _pop();
SK_PROGRAM skbool _string_eq(skstring a, skstring b);
SK_PROGRAM skstring _string_plus(skstring a, skstring b);
SK_PROGRAM void _write_to_fd(int fd, skbyteptr buf, int buf_len);
SK_PROGRAM void print(sktype t);
SK_PROGRAM void println(sktype t);`)

    writeln(&gen.builtinprocs, `SK_PROGRAM void _push(skvalue v) {
	assert(g_stack.top < SKSTACK_SIZE);
	g_stack.values[++g_stack.top] = v;
}

SK_PROGRAM skvalue _pop() {
	assert(g_stack.top > -1);
	skvalue v = g_stack.values[g_stack.top];
	g_stack.top--;
	return v;
}

SK_PROGRAM skbool _string_eq(skstring s1, skstring s2) {
	if (s1.len != s2.len) {
		return SKFALSE;
	}
	// Unsafe
	return memcmp(s1.data, s2.data, s1.len) == 0 ? SKTRUE : SKFALSE;
}

SK_PROGRAM skstring _string_plus(skstring s1, skstring s2) {
	int rlen = s1.len + s2.len; // result len
	skbyteptr rstr = (skbyteptr)malloc(sizeof(skbyte) * rlen); // result str
	{ // Unsafe block
		memcpy(rstr, s1.data, s1.len);
		memcpy(rstr + s1.len, s2.data, s2.len);
		rstr[rlen] = 0;
	}
	return (skstring){.data=rstr,.len=rlen};
}

SK_PROGRAM void _write_to_fd(int fd, skbyteptr buf, int buf_len) {
	skbyteptr ptr = buf;
	size_t remaining_bytes = ((size_t)(buf_len));
	size_t x = ((size_t)(0));
	voidptr stream = ((voidptr)(stdout));
	if (fd == 2) stream = ((voidptr)(stderr));
	{ // Unsafe block
		for (;;) {
			if (!(remaining_bytes > 0)) break;
			x = ((size_t)(fwrite(ptr, 1, remaining_bytes, stream)));
			ptr += x;
			remaining_bytes -= x;
		}
	}
}

SK_PROGRAM void print(sktype t) {
	skvalue a = _pop();
	switch (t) {
		case skbool_t: printf("%s", a.skbool == SKTRUE ? "true" : "false"); break;
		case skfloat_t: printf("%g", a.skfloat); break;
		case skint_t: printf("%li", a.skint); break;
		case skuint_t: printf("%lu", a.skuint); break;
		case skstring_t: _write_to_fd(0, a.skstring.data, a.skstring.len); break;
		default: assert(SKFALSE);
	}
}

SK_PROGRAM void println(sktype t) {
    print(t);
	skbyte lf = ((skbyte)('\n'));
	_write_to_fd(0, &lf, 1);
}`)
}

gen_function_declaration :: proc(f: ^Function) {
    c := &gen.userdefs

    writefln(
        c, "// {} ({}:{}:{})",
        f.name, f.filename, f.line, f.column,
    )
    writefln(c, "SK_PROGRAM void skfuncip{}();", f.address)
}

gen_function :: proc(f: ^Function, part: enum { Head, Tail }) {
    c := &f.code
    switch part {
    case .Head:
        writefln(
            f, "// {} ({}:{}:{})",
            f.name, f.filename, f.line, f.column,
        )
        writefln(f, "SK_PROGRAM void skfuncip{}() {{", f.address)
        indent_forward(f)
        writeln(f, "skvalue a, b, c;")
    case .Tail:
        indent_backward(f)
        writeln(f, "}")
        writeln(&gen.userfuncs, strings.to_string(f.code))
    }
}

gen_push_bool :: proc(f: ^Function, v: string) {
    writefln(f, "a.skbool = {}; _push(a);", v)
}

gen_push_float :: proc(f: ^Function, v: f64) {
    writefln(f, "a.skfloat = {}; _push(a);", v)
}

gen_push_int :: proc(f: ^Function, v: int) {
    writefln(f, "a.skint = {}; _push(a);", v)
}

gen_push_uint :: proc(f: ^Function, v: u64) {
    writefln(f, "a.skuint = {}u; _push(a);", v)
}

gen_push_string :: proc(f: ^Function, v: string) {
    writefln(f, "a.skstring = __STRLIT(\"{}\", {}); _push(a);", v, len(v))
}

gen_push_binding :: proc(f: ^Function, address: uint) {
    writefln(f, "_push(sklocalip{});", address)
}

gen_literal_c :: proc(f: ^Function, format: string, args: ..any) {
    writefln(f, format, ..args)
}

gen_function_call :: proc(f: ^Function, address: uint) {
    writefln(f, "skfuncip{}();", address)
}

gen_add :: proc(f: ^Function, t: Type_Kind) {
    writeln(f, "b = _pop(); a = _pop();")

    if t == .String {
        writeln(f, "a.skstring = _string_plus(a.skstring, b.skstring);")
        writeln(f, "_push(a);")
    } else {
        writefln(f, "a.{0} = a.{0} + b.{0}; _push(a);", type_to_cname(t))
    }
}

gen_divide :: proc(f: ^Function, t: Type_Kind) {
    writeln(f, "b = _pop(); a = _pop();")
    writefln(f, "a.{0} = a.{0} / b.{0}; _push(a);", type_to_cname(t))
}

gen_modulo :: proc(f: ^Function, t: Type_Kind) {
    writeln(f, "b = _pop(); a = _pop();")
    writefln(f, "a.{0} = a.{0} %% b.{0}; _push(a);", type_to_cname(t))
}

gen_multiply :: proc(f: ^Function, t: Type_Kind) {
    writeln(f, "b = _pop(); a = _pop();")
    writefln(f, "a.{0} = a.{0} * b.{0}; _push(a);", type_to_cname(t))
}

gen_substract :: proc(f: ^Function, t: Type_Kind) {
    writeln(f, "b = _pop(); a = _pop();")
    writefln(f, "a.{0} = a.{0} - b.{0}; _push(a);", type_to_cname(t))
}

gen_equal :: proc(f: ^Function, t: Type_Kind) {
    writeln(f, "b = _pop(); a = _pop();")
    write(f, "a.skbool = ")

    if t == .String {
        write(f, "_string_eq(a.skstring, b.skstring); ")
    } else {
        writef(f, "a.{0} == b.{0}; ", type_to_cname(t))
    }
    writefln(f, "_push(a);")
}

gen_greater_equal :: proc(f: ^Function, t: Type_Kind) {
    writeln(f, "b = _pop(); a = _pop();")
    writefln(f, "a.skbool = a.{0} >= b.{0}; _push(a);", type_to_cname(t))
}

gen_greater_than :: proc(f: ^Function, t: Type_Kind) {
    writeln(f, "b = _pop(); a = _pop();")
    writefln(f, "a.skbool = a.{0} > b.{0}; _push(a);", type_to_cname(t))
}

gen_less_equal :: proc(f: ^Function, t: Type_Kind) {
    writeln(f, "b = _pop(); a = _pop();")
    writefln(f, "a.skbool = a.{0} <= b.{0}; _push(a);", type_to_cname(t))
}

gen_less_than :: proc(f: ^Function, t: Type_Kind) {
    writeln(f, "b = _pop(); a = _pop();")
    writefln(f, "a.skbool = a.{0} < b.{0}; _push(a);", type_to_cname(t))
}

gen_not_equal :: proc(f: ^Function, t: Type_Kind) {
    writeln(f, "b = _pop(); a = _pop();")
    write(f, "a.skbool = ")

    if t == .String {
        write(f, "!_string_eq(a.skstring, b.skstring); ")
    } else {
        writef(f, "a.{0} != b.{0}; ", type_to_cname(t))
    }
    writefln(f, "_push(a);")
}

gen_binding :: proc(f: ^Function, address: uint) {
    writefln(f, "skvalue sklocalip{} = _pop();", address)
}

gen_code_block :: proc(f: ^Function, part: enum { start, end }) {
    switch part {
    case .start:
        writeln(f, "{")
        indent_forward(f)
    case .end:
        indent_backward(f)
        writeln(f, "}")
    }
}

gen_if_statement :: proc(f: ^Function, part: enum { s_if, s_else, fi }) {
    switch part {
    case .s_if:
        writeln(f, "a = _pop();")
        writeln(f, "if (a.skbool) {")
        indent_forward(f)
    case .s_else:
        indent_backward(f)
        writeln(f, "} else {")
        indent_forward(f)
    case .fi:
        indent_backward(f)
        writeln(f, "}")
    }
}
