package main

import "core:fmt"
import "core:os/os2"
import "core:reflect"
import "core:slice"
import "core:strings"

Generator :: struct {
    head:          strings.Builder,
    multi:         strings.Builder,
    sk_code:       strings.Builder,
    code:          strings.Builder,
    defs:          strings.Builder,
    indent:        int,

    source:        ^strings.Builder,
    multi_results: [dynamic]string,
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

gen_multiresult_string :: proc{
    gen_multiresult_string_from_registers,
    gen_multiresult_string_from_params,
    gen_multiresult_string_from_types,
}

gen_multiresult_string_from_registers :: proc(gen: ^Generator, params: []^Register) -> string {
    types_array := make([]^Type, len(params), context.temp_allocator)

    for param, index in params {
        types_array[index] = param.type
    }

    result := gen_multiresult_string_from_types(gen, types_array)
    return result
}

gen_multiresult_string_from_params :: proc(gen: ^Generator, params: []Parameter) -> string {
    types_array := make([]^Type, len(params), context.temp_allocator)

    for param, index in params {
        types_array[index] = param.type
    }

    result := gen_multiresult_string_from_types(gen, types_array)
    return result
}

gen_multiresult_string_from_types :: proc(gen: ^Generator, params: []^Type) -> string {
    result := strings.builder_make(context.temp_allocator)

    strings.write_string(&result, "sk_result_")

    for param, index in params {
        strings.write_string(&result, param.foreign_name)
        if index < len(params)-1 do strings.write_string(&result, "_")
    }

    index, found := slice.binary_search(gen.multi_results[:], strings.to_string(result))

    if !found {
        result_str := strings.to_string(result)

        append(&gen.multi_results, strings.clone(result_str))

        fmt.sbprintf(&gen.multi, "typedef struct {} {{\n", result_str)
        for param, index in params {
            fmt.sbprintf(&gen.multi, "\t{} p{};\n", param.foreign_name, index)
        }
        fmt.sbprintf(&gen.multi, "} {};\n\n", result_str)

        return result_str
    }

    return gen.multi_results[index]
}

gen_register :: proc(gen: ^Generator, reg: ^Register) {
    gen_printf(gen, "r%2d", reg.index)
}

gen_bootstrap :: proc(gen: ^Generator) {
    gen.source = &gen.head
    gen_print(gen, "#include <stdio.h>\n")
    gen_print(gen, "#include <stdint.h>\n")
    gen_print(gen, "\n")

    gen_print(gen, "// Stanczyk Builtin Types\n")
    gen_print(gen, "typedef int64_t  s64;\n")
    gen_print(gen, "typedef int32_t  s32;\n")
    gen_print(gen, "typedef int16_t  s16;\n")
    gen_print(gen, "typedef int8_t   s8;\n")
    gen_print(gen, "typedef uint64_t u64;\n")
    gen_print(gen, "typedef uint32_t u32;\n")
    gen_print(gen, "typedef uint16_t u16;\n")
    gen_print(gen, "typedef uint8_t  u8;\n")
    gen_print(gen, "typedef int8_t   b8;\n")
    gen_print(gen, "typedef double   f64;\n")
    gen_print(gen, "typedef float    f32;\n")
    gen_print(gen, "\n")

    gen_print(gen, "#define SK_EXPORT extern __declspec(dllexport)\n")
    gen_print(gen, "#define SK_INLINE static inline\n")
    gen_print(gen, "#define SK_STATIC static\n")
    gen_print(gen, "#define STR_LIT(s) ((string){.data=(u8*)(\"\" s), .length=(sizeof(s)-1)})\n")
    gen_print(gen, "#define SK_TRUE  1\n")
    gen_print(gen, "#define SK_FALSE 0\n")
    gen_print(gen, "\n")

    // string type
    gen_print(gen, "typedef struct string {\n")
    gen_print(gen, "\tu8* data;\n")
    gen_print(gen, "\ts64 length;\n")
    gen_print(gen, "} string;\n")

    gen.source = &gen.multi
    gen_print(gen, "// Stanczyk Multireturn types\n")

    gen.source = &gen.sk_code
    gen_print(gen, "// Stanczyk Internal Procedures\n")
    gen_print(gen, "SK_STATIC void print_b8(b8 v) { printf(\"%s\\n\", v == SK_TRUE ? \"true\" : \"false\"); }\n")
    gen_print(gen, "SK_STATIC void print_u8(u8 v) { printf(\"%d\\n\", v); }\n")
    gen_print(gen, "SK_STATIC void print_f64(f64 v) { printf(\"%g\\n\", v); }\n")
    gen_print(gen, "SK_STATIC void print_s64(s64 v) { printf(\"%lli\\n\", v); }\n")
    gen_print(gen, "SK_STATIC void print_u64(u64 v) { printf(\"%llu\\n\", v); }\n")
    gen_print(gen, "SK_STATIC void print_string(string v) { printf(\"%s\\n\", v.data); }\n")

    gen.source = &gen.defs
    gen_print(gen, "// User Definitions\n")

    gen.source = &gen.code
    gen_print(gen, "// User Code\n")

}

gen_program :: proc() {
    gen := new(Generator)
    gen.head    = strings.builder_make()
    gen.multi   = strings.builder_make()
    gen.sk_code = strings.builder_make()
    gen.defs    = strings.builder_make()
    gen.code    = strings.builder_make()

    gen_bootstrap(gen)

    for procedure in bytecode {
        gen_procedure(gen, procedure)
    }

    write_file(gen)
}

gen_procedure :: proc(gen: ^Generator, procedure: ^Procedure) {
    _gen_proc_header_line :: proc(gen: ^Generator, procedure: ^Procedure) {
        type_string := "void"

        if len(procedure.results) == 1 {
            type_string = procedure.results[0].type.foreign_name
        } else if len(procedure.results) > 1 {
            type_string = gen_multiresult_string(gen, procedure.results)
        }

        gen_printf(gen, "SK_STATIC {} {}(", type_string, procedure.foreign_name)

        for arg, index in procedure.arguments {
            gen_printf(gen, "{} arg{}", arg.type.foreign_name, index)
            if index < len(procedure.arguments)-1 {
                gen_print(gen, ", ")
            }
        }

        gen_print(gen, ")")
    }

    gen.source = &gen.defs
    _gen_proc_header_line(gen, procedure)
    gen_print(gen, ";\n")

    gen.source = &gen.code
    _gen_proc_header_line(gen, procedure)
    gen_begin_scope(gen)

    registers_copy := slice.clone(procedure.registers[:], context.temp_allocator)
    slice.stable_sort_by(registers_copy[:], proc(i, j: ^Register) -> bool {
        return i.type != j.type
    })

    gen_indent(gen)
    last_type := registers_copy[0].type
    gen_printf(gen, "{} ", last_type.foreign_name)
    count := 0

    for reg, index in registers_copy {
        if last_type != reg.type {
            gen_printf(gen, ";\n")
            gen_indent(gen)
            gen_printf(gen, "{} ", reg.type.foreign_name)
            last_type = reg.type
            count = 0
        }

        gen_register(gen, reg)

        if index < len(registers_copy)-1 && registers_copy[index + 1].type == last_type {
            gen_print(gen, ", ")

            if (count + 1) % 10 == 0 {
                gen_print(gen, "\n")
                gen_indent(gen)
            }
        }

        count += 1
    }
    gen_print(gen, ";\n")

    for ins in procedure.code {
        gen_instruction(gen, procedure, ins)
    }

    gen_end_scope(gen)
}

gen_instruction :: proc(gen: ^Generator, this_proc: ^Procedure, ins: ^Instruction) {
    _string_value :: proc(s: string) -> string {
        // removes the starting " and ending " if exists
        if strings.starts_with(s, "\"") && strings.ends_with(s, "\"") {
            return s[1:len(s)-1]
        }
        return s
    }

    gen_printf(
        gen, "_ip{}:;\t// {}\n", ins.offset, reflect.union_variant_type_info(ins.variant),
    )

    switch v in ins.variant {
    case BINARY_ADD:
        gen_indent(gen)
        gen_register(gen, ins.register)
        gen_print(gen, " = ")
        gen_register(gen, v.lhs)
        gen_print(gen, " + ")
        gen_register(gen, v.rhs)
        gen_print(gen, ";\n")

    case BINARY_MINUS:
        gen_indent(gen)
        gen_register(gen, ins.register)
        gen_print(gen, " = ")
        gen_register(gen, v.lhs)
        gen_print(gen, " - ")
        gen_register(gen, v.rhs)
        gen_print(gen, ";\n")

    case BINARY_MULTIPLY:
        gen_indent(gen)
        gen_register(gen, ins.register)
        gen_print(gen, " = ")
        gen_register(gen, v.lhs)
        gen_print(gen, " * ")
        gen_register(gen, v.rhs)
        gen_print(gen, ";\n")

    case BINARY_MODULO:
        gen_indent(gen)
        gen_register(gen, ins.register)
        gen_print(gen, " = ")
        gen_register(gen, v.lhs)
        gen_print(gen, " % ")
        gen_register(gen, v.rhs)
        gen_print(gen, ";\n")

    case BINARY_SLASH:
        gen_indent(gen)
        gen_register(gen, ins.register)
        gen_print(gen, " = ")
        gen_register(gen, v.lhs)
        gen_print(gen, " / ")
        gen_register(gen, v.rhs)
        gen_print(gen, ";\n")

    case CAST:

    case DROP:

    case DUP:

    case DUP_PREV:

    case IDENTIFIER:

    case INVOKE_PROC:
        gen_indent(gen)
        has_multiresults := len(v.results) > 1

        if has_multiresults {
            type := gen_multiresult_string(gen, v.results)
            gen_printf(gen, "{} sk_result{}", type, ins.offset)
            gen_print(gen, " = ")
        } else if len(v.results) == 1 {
            gen_register(gen, v.results[0])
            gen_print(gen, " = ")
        }

        gen_printf(gen, "{}(", v.procedure.foreign_name)
        for value, index in v.arguments {
            gen_register(gen, value)

            if index < len(v.arguments)-1 {
                gen_print(gen, ", ")
            }
        }
        gen_print(gen, ");\n")

        if has_multiresults {
            for result, index in v.results {
                gen_indent(gen)
                gen_register(gen, result)
                gen_printf(gen, " = sk_result{}.p{};\n", ins.offset, index)
            }
        }

    case NIP:

    case OVER:

    case PRINT:
        gen_indent(gen)
        gen_printf(gen, "print_{}(", v.param.type.foreign_name)
        gen_register(gen, v.param)
        gen_print(gen, ");\n")

    case PUSH_ARG:
        gen_indent(gen)
        gen_register(gen, ins.register)
        gen_printf(gen, " = arg{};\n", v.value)

    case PUSH_BIND:

    case PUSH_BOOL:
        gen_indent(gen)
        gen_register(gen, ins.register)
        gen_printf(gen, " = {};\n", v.value ? "SK_TRUE" : "SK_FALSE")

    case PUSH_BYTE:
        gen_indent(gen)
        gen_register(gen, ins.register)
        gen_printf(gen, " = {};\n", v.value)


    case PUSH_CONST:
        gen_indent(gen)
        gen_register(gen, ins.register)
        gen_print(gen, " = ")
        switch value in v.const.value {
        case bool:   gen_printf(gen, "{}", value ? "SK_TRUE" : "SK_FALSE")
        case f64:    gen_printf(gen, "{}", value)
        case i64:    gen_printf(gen, "{}", value)
        case string: gen_printf(gen, "STR_LIT(\"{}\")", _string_value(value))
        case u64:    gen_printf(gen, "{}", value)
        }
        gen_print(gen, ";\n")

    case PUSH_FLOAT:
        gen_indent(gen)
        gen_register(gen, ins.register)
        gen_printf(gen, " = {};\n", v.value)

    case PUSH_INT:
        gen_indent(gen)
        gen_register(gen, ins.register)
        gen_printf(gen, " = {};\n", v.value)

    case PUSH_STRING:
        gen_indent(gen)
        gen_register(gen, ins.register)
        gen_printf(gen, " = STR_LIT(\"{}\");\n", _string_value(v.value))

    case PUSH_TYPE:

    case PUSH_UINT:
        gen_indent(gen)
        gen_register(gen, ins.register)
        gen_printf(gen, " = {};\n", v.value)

    case RETURN:
        gen_indent(gen)
        gen_print(gen, "return;\n")

    case RETURN_VALUE:
        gen_indent(gen)
        gen_print(gen, "return ")
        gen_register(gen, v.value)
        gen_print(gen, ";\n")

    case RETURN_VALUES:
        type := gen_multiresult_string(gen, v.value)
        gen_indent(gen)
        gen_printf(gen, "return ({}){{", type)
        for arg, index in v.value {
            gen_printf(gen, ".p{}=", index)
            gen_register(gen, arg)
            if index < len(v.value)-1 {
                gen_print(gen, ", ")
            }
        }
        gen_print(gen, "};\n")

    case ROTATE_LEFT:

    case ROTATE_RIGHT:

    case STORE_BIND:

    case SWAP:

    case TUCK:

    }
}

write_file :: proc(gen: ^Generator) {
    result := strings.builder_make()
    strings.write_string(&result, strings.to_string(gen.head))
    strings.write_string(&result, "\n")
    strings.write_string(&result, strings.to_string(gen.multi))
    strings.write_string(&result, "\n")
    strings.write_string(&result, strings.to_string(gen.sk_code))
    strings.write_string(&result, "\n")
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

    error := os2.write_entire_file(fmt.tprintf("{}.c", output_filename), result.buf[:])
    if error != nil {
        fatalf(.Generator, "could not generate output file")
    }
}
