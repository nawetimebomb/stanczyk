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

    userprocdefs: strings.Builder,
    userprocs:    strings.Builder,

    indentation: int,
    global_ip:   uint,
}

gen := Generator{}

write :: proc(s: ^strings.Builder, args: ..any) {
    fmt.sbprint(s, args = args)
}

writef :: proc(s: ^strings.Builder, format: string, args: ..any) {
    fmt.sbprintf(s, fmt = format, args = args)
}

writeln :: proc(s: ^strings.Builder, args: ..any) {
    write(s, args = args)
    write(s, "\n")
    write_indentation(s)
}

writefln :: proc(s: ^strings.Builder, format: string, args: ..any) {
    fmt.sbprintf(s, fmt = format, args = args)
    write(s, "\n")
    write_indentation(s)
}

write_indentation :: proc(s: ^strings.Builder) {
    if gen.indentation > 0 {
        indentation_str := "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"
        write(s, indentation_str[:clamp(gen.indentation, 0, len(indentation_str) - 1)])
    }
}

reindentation :: proc(s: ^strings.Builder) {
    for s.buf[len(s.buf) - 1] == '\t' { pop(&s.buf) }
    write_indentation(s)
}

indentation_forward :: proc(s: ^strings.Builder, should_write := true) {
    gen.indentation += 1
    if should_write { write_indentation(s) }
}

indentation_backward :: proc(s: ^strings.Builder, should_write := true) {
    gen.indentation = max(gen.indentation - 1, 0)
    if should_write {
        reindentation(s)
        write_indentation(s)
    }
}

gen_file :: proc() {
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
    writeln(&result, string(gen.userprocdefs.buf[:]))
    clear(&gen.userprocdefs.buf)
    writeln(&result, string(gen.userprocs.buf[:]))
    clear(&gen.userprocs.buf)
    writeln(&result, `int main(int ___argc, char** ___argv) {
	g_main_argc = ___argc;
	g_main_argv = ___argv;
	main__main();
	return 0;
}`)
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
	skstring_t, skbool_t, skint_t, skfloat_t,
};

union skvalue {
	skbool skbool;
	skbyte skbyte;
	skfloat skfloat;
	skint skint;
	skstring skstring;
};

struct skstack {
	skint top;
	skvalue values[SKSTACK_SIZE];
};`)

    writeln(&gen.builtinglobals, `SK_PROGRAM skstack g_stack;
int g_main_argc = ((int)(0));
void* g_main_argv = ((void*)0);`)

    writeln(&gen.builtinprocdefs, `SK_PROGRAM void _write_to_fd(int fd, uint8_t* buf, int buf_len);
SK_PROGRAM void _push(skvalue v);
SK_PROGRAM skvalue _pop();
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

SK_PROGRAM void _write_to_fd(int fd, uint8_t* buf, int buf_len) {
	uint8_t* ptr = buf;
	size_t remaining_bytes = ((size_t)(buf_len));
	size_t x = ((size_t)(0));
	void* stream = ((void*)(stdout));
	if (fd == 2) stream = ((void*)(stderr));
	{ // Unsafe
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
		case skstring_t: printf("%.*s", (int)a.skstring.len, a.skstring.data); break;
		default: assert(SKFALSE);
	}
	// _write_to_fd(0, s.data, s.len);
}

SK_PROGRAM void println(sktype t) {
    print(t);
	skvalue a = (skvalue){.skstring = __STRLIT("\n", 1)};
    _push(a);
    print(skstring_t);
	// uint8_t lf = ((uint8_t)('\n'));
	// _write_to_fd(0, s.data, s.len);
	// _write_to_fd(0, &lf, 1);
}`)
}

gen_proc :: proc(p: ^Procedure_B, part: enum { Head, Tail }) {
    gproc := &gen.userprocs
    gdef := &gen.userprocdefs
    switch part {
    case .Head:
        writefln(gdef, "SK_PROGRAM void {}();", p.name)
        writefln(gproc, "SK_PROGRAM void {}() {{", p.name)
        indentation_forward(gproc)
        writeln(gproc, "skvalue a, b, c;")
    case .Tail:
        indentation_backward(gproc)
        writeln(gproc, "}")
    }
}

gen_push_literal :: proc(type: Type_Kind_B, value: string) {
    s := &gen.userprocs
    writef(s, "a.{} = ", type_to_cname(type))
    #partial switch type {
        case .Bool: writef(s, "{}", value == "true" ? "SKTRUE" : "SKFALSE")
        case .Float: writef(s, "{}", strconv.atof(value))
        case .Int: writef(s,"{}", strconv.atoi(value))
        case .String: writef(s, "__STRLIT(\"{}\", {})", value, len(value))
    }
    writeln(s, "; _push(a);")
}

gen_arithmetic :: proc(
    l, r, res: Type_Kind_B, op: enum { add, sub, mul, div, mod },
) {
    s := &gen.userprocs
    opstr: string

    switch op {
    case .add: opstr = "+"
    case .sub: opstr = "-"
    case .mul: opstr = "*"
    case .div: opstr = "/"
    case .mod: opstr = "%"
    }

    writeln(s, "b = _pop(); a = _pop();")
    writef(s, "a.{} = ", type_to_cname(res))
    writef(s, "a.{} ", type_to_cname(l))
    write(s, opstr)
    writefln(s, " b.{}; _push(a);", type_to_cname(r))
}

gen_internal_proc_call :: proc(i: Internal_Procedure, args: ..Type_Kind_B) {
    s := &gen.userprocs

    switch i {
    case .Drop:
    case .Dup:
    case .Print: fallthrough
    case .Println:
        t := args[0]
        writefln(s, "{}({}_t);", i == .Print ? "print" : "println", type_to_cname(t))
    case .Swap:
    }
}
