package main

import "core:fmt"
import "core:os/os2"
import "core:reflect"
import "core:slice"
import "core:strings"

Generator :: struct {
    prepend:       strings.Builder,
    bss_segment:   strings.Builder,
    data_segment:  strings.Builder,
    text_segment:  strings.Builder,

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

gen_bootstrap :: proc(gen: ^Generator) {
    gen.source = &gen.prepend
    gen_print (gen, "FORMAT ELF64\n")
    gen_print (gen, "public _start\n")
    gen_print (gen, "extrn exit\n")
    gen_print (gen, "extrn printf\n")
    gen_print (gen, "extrn puts\n")
    gen_print (gen, "extrn putchar\n")
    gen_print (gen, "extrn strcmp\n")

    gen.source = &gen.data_segment
    gen_print (gen, "section '.data' writeable\n")
    gen_print (gen, "args_ptr:           rq 1\n")
    gen_print (gen, "ret_stack_ptr:      rq 1\n")
    gen_print (gen, "ret_stack:          rb 65535\n")
    gen_print (gen, "ret_stack_ptr_end:\n")
    gen_printf(gen, "stanczyk_static:    rb {}\n", compiler.mem_size)
    gen_print (gen, "EMPTY_STRING:       db 0\n")
    gen_print (gen, "FORMAT_BOOL:        db \"%s\",10,0\n")
    gen_print (gen, "FORMAT_FLOAT:       db \"%g\",10,0\n")
    gen_print (gen, "FORMAT_INT:         db \"%d\",10,0\n")
    gen_print (gen, "FORMAT_UINT:        db \"%u\",10,0\n")

    gen_print (gen, "TRUE_STR:           db \"true\",0\n")
    gen_print (gen, "FALSE_STR:          db \"false\",0\n")
    gen_print (gen, "SK_TRUE             db 1\n")
    gen_print (gen, "SK_FALSE            db 0\n")

    for const in compiler.constants_table {
        gen_printf(gen, "CONST{}: ", const.index)

        switch v in const.value {
        case bool:
            gen_printf(gen, "db {}\n", v ? 1 : 0)

        case f64:
            gen_printf(gen, "dq {}\n", v)

        case i64:
            gen_printf(gen, "dq {}\n", v)

        case u64:
            gen_printf(gen, "dq {}\n", v)

        case byte:
            gen_printf(gen, "db {}\n", v)

        case string:
            gen_print(gen, "db ")

            for index := 0; index < len(v); index += 1 {
                char := v[index]

                if char == '\\' {
                    index += 1
                    char = v[index]
                    char_number: int

                    switch char {
                    case 'a':  char_number = 7
                    case 'b':  char_number = 8
                    case 't':  char_number = 9
                    case 'n':  char_number = 10
                    case 'v':  char_number = 11
                    case 'f':  char_number = 12
                    case 'r':  char_number = 13
                    case 'e':  char_number = 27
                    case '"':  char_number = 34
                    case '\'': char_number = 39
                    case:      char_number = int(char)
                    }

                    gen_printf(gen, "{},", char_number)
                } else {
                    gen_printf(gen, "{},", int(char))
                }
            }
            gen_print(gen, "0\n")
        }
    }

    gen.source = &gen.text_segment
    gen_print (gen, "section '.text' executable\n")
    gen_print (gen, "_start:\n")
    gen_print (gen, "    mov     [args_ptr], rsp\n")
    gen_print (gen, "    mov     rax, ret_stack_ptr_end\n")

    // TODO(nawe) global code here

    gen_print (gen, ".stanczyk_user_program:\n")
    gen_print (gen, "    mov     [ret_stack_ptr], rax\n")
    gen_print (gen, "    mov     rax, rsp\n")
    gen_print (gen, "    mov     rsp, [ret_stack_ptr]\n")
    gen_printf(gen, "    call    proc{}\n", compiler.main_proc_uid)
    gen_print (gen, "    mov     [ret_stack_ptr], rsp\n")
    gen_print (gen, "    mov     rsp, rax\n")
    gen_print (gen, "    mov     rdi, 0\n")
    gen_print (gen, "    call    exit\n")

    gen_print (gen, "; code starts here\n")

}

gen_program :: proc() {
    gen := new(Generator)
    gen.prepend      = strings.builder_make()
    gen.bss_segment  = strings.builder_make()
    gen.data_segment = strings.builder_make()
    gen.text_segment = strings.builder_make()

    gen_bootstrap(gen)

    for procedure in bytecode {
        gen_procedure(gen, procedure)
    }

    gen_print (gen, "; code ends here\n")

    write_file(gen)
}

gen_procedure :: proc(gen: ^Generator, procedure: ^Procedure) {
    gen_printf(gen, "proc{}: ; {}\n", procedure.id, procedure.name)
    gen_printf(gen, "    sub     rsp, {}\n", procedure.stack_frame_size)
    gen_print (gen, "    mov     [ret_stack_ptr], rsp\n")
    gen_print (gen, "    mov     rsp, rax\n")


    for ins in procedure.code {
        gen_instruction(gen, procedure, ins)
    }
}


gen_instruction :: proc(gen: ^Generator, this_proc: ^Procedure, ins: ^Instruction) {
    gen_printf(gen, ".ip{}:\n", ins.offset)
    switch v in ins.variant {
    case BINARY_ADD:
        // TODO(nawe) support types
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    add     rax, rbx\n")
        gen_print (gen, "    push    rax\n")

    case BINARY_DIVIDE:
        gen_print (gen, "    xor     rdx, rdx\n")
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    div     rbx\n")
        gen_print (gen, "    push    rax\n")

    case BINARY_MINUS:
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    sub     rax, rbx\n")
        gen_print (gen, "    push    rax\n")

    case BINARY_MULTIPLY:
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    mul     rbx\n")
        gen_print (gen, "    push    rax\n")

    case BINARY_MODULO:
        gen_print (gen, "    xor     rdx, rdx\n")
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    div     rbx\n")
        gen_print (gen, "    push    rdx\n")

    case CAST:

    case COMPARE_EQUAL:
        if v.type == type_string {
            gen_print (gen, "    mov     rcx, SK_FALSE\n")
            gen_print (gen, "    mov     rdx, SK_TRUE\n")
            gen_print (gen, "    xor     rax, rax\n")
            gen_print (gen, "    pop     rsi\n")
            gen_print (gen, "    pop     rdi\n")
            gen_print (gen, "    call    strcmp\n")
            gen_print (gen, "    cmp     rax, 0\n")
            gen_print (gen, "    cmove   rcx, rdx\n")
            gen_print (gen, "    push    rcx\n")
        } else {
            gen_print (gen, "    mov     rcx, SK_FALSE\n")
            gen_print (gen, "    mov     rdx, SK_TRUE\n")
            gen_print (gen, "    pop     rbx\n")
            gen_print (gen, "    pop     rax\n")
            gen_print (gen, "    cmp     rax, rbx\n")
            gen_print (gen, "    cmove   rcx, rdx\n")
            gen_print (gen, "    push    rcx\n")
        }

    case COMPARE_NOT_EQUAL:
        if v.type == type_string {
            gen_print (gen, "    mov     rcx, SK_FALSE\n")
            gen_print (gen, "    mov     rdx, SK_TRUE\n")
            gen_print (gen, "    xor     rax, rax\n")
            gen_print (gen, "    pop     rsi\n")
            gen_print (gen, "    pop     rdi\n")
            gen_print (gen, "    call    strcmp\n")
            gen_print (gen, "    cmp     rax, 0\n")
            gen_print (gen, "    cmovne  rcx, rdx\n")
            gen_print (gen, "    push    rcx\n")
        } else {
            gen_print (gen, "    mov     rcx, SK_FALSE\n")
            gen_print (gen, "    mov     rdx, SK_TRUE\n")
            gen_print (gen, "    pop     rbx\n")
            gen_print (gen, "    pop     rax\n")
            gen_print (gen, "    cmp     rax, rbx\n")
            gen_print (gen, "    cmovne  rcx, rdx\n")
            gen_print (gen, "    push    rcx\n")
        }

    case COMPARE_GREATER:
        gen_print (gen, "    mov     rcx, SK_FALSE\n")
        gen_print (gen, "    mov     rdx, SK_TRUE\n")
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    cmp     rax, rbx\n")
        gen_print (gen, "    cmovg   rcx, rdx\n")
        gen_print (gen, "    push    rcx\n")

    case COMPARE_GREATER_EQUAL:
        gen_print (gen, "    mov     rcx, SK_FALSE\n")
        gen_print (gen, "    mov     rdx, SK_TRUE\n")
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    cmp     rax, rbx\n")
        gen_print (gen, "    cmovge  rcx, rdx\n")
        gen_print (gen, "    push    rcx\n")

    case COMPARE_LESS:
        gen_print (gen, "    mov     rcx, SK_FALSE\n")
        gen_print (gen, "    mov     rdx, SK_TRUE\n")
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    cmp     rax, rbx\n")
        gen_print (gen, "    cmovl   rcx, rdx\n")
        gen_print (gen, "    push    rcx\n")

    case COMPARE_LESS_EQUAL:
        gen_print (gen, "    mov     rcx, SK_FALSE\n")
        gen_print (gen, "    mov     rdx, SK_TRUE\n")
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    cmp     rax, rbx\n")
        gen_print (gen, "    cmovle  rcx, rdx\n")
        gen_print (gen, "    push    rcx\n")

    case DECLARE_VAR_END:

    case DECLARE_VAR_START:

    case DROP:
        gen_print (gen, "    pop     rax\n")

    case DUP:
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rax\n")
        gen_print (gen, "    push    rax\n")

    case DUP_PREV:
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rax\n")
        gen_print (gen, "    push    rax\n")
        gen_print (gen, "    push    rbx\n")

    case IDENTIFIER:

    case IF_ELSE_JUMP:

    case IF_END:

    case IF_FALSE_JUMP:

    case INVOKE_PROC:
        gen_print (gen, "    mov     rax, rsp\n")
        gen_print (gen, "    mov     rsp, [ret_stack_ptr]\n")
        gen_printf(gen, "    call    proc{} ; {}\n", v.procedure.id, v.procedure.name)
        gen_print (gen, "    mov     [ret_stack_ptr], rsp\n")
        gen_print (gen, "    mov     rsp, rax\n")

    case NIP:
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rbx\n")

    case OVER:
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rax\n")
        gen_print (gen, "    push    rbx\n")
        gen_print (gen, "    push    rax\n")

    case PRINT:
        #partial switch variant in v.type.variant {
        case Type_Basic:
            switch variant.kind {
            case .Bool:
                gen_print(gen, "    mov     rdi, FORMAT_BOOL\n")
                gen_print(gen, "    mov     rdx, TRUE_STR\n")
                gen_print(gen, "    mov     rsi, FALSE_STR\n")
                gen_print(gen, "    xor     rbx, rbx\n")
                gen_print(gen, "    pop     rbx\n")
                gen_print(gen, "    cmp     rbx, SK_TRUE\n")
                gen_print(gen, "    cmove   rsi, rdx\n")
                gen_print(gen, "    xor     rax, rax\n")
                gen_print(gen, "    call    printf\n")
            case .Byte:
                gen_print(gen, "    xor     rdi, rdi\n")
                gen_print(gen, "    pop     rdi\n")
                gen_print(gen, "    call    putchar\n")
                gen_print(gen, "    mov     rdi, 10\n")
                gen_print(gen, "    call    putchar\n")
            case .Float:
                gen_print(gen, "    mov     rdi, FORMAT_FLOAT\n")
                gen_print(gen, "    pop     rbx\n")
                gen_print(gen, "    movq    xmm0, rbx\n")
                gen_print(gen, "    mov     rax, 1\n")
                gen_print(gen, "    call    printf\n")
            case .Int:
                gen_print(gen, "    mov     rdi, FORMAT_INT\n")
                gen_print(gen, "    pop     rsi\n")
                gen_print(gen, "    xor     rax, rax\n")
                gen_print(gen, "    call    printf\n")
            case .String:
                gen_print(gen, "    pop     rdi\n")
                gen_print(gen, "    call    puts\n")
            case .Uint:
                gen_print(gen, "    mov     rdi, FORMAT_UINT\n")
                gen_print(gen, "    pop     rsi\n")
                gen_print(gen, "    xor     rax, rax\n")
                gen_print(gen, "    call    printf\n")
            }
        }

    case PUSH_BIND:
        gen_print (gen, "    mov     rax, [ret_stack_ptr]\n")
        gen_printf(gen, "    add     rax, {}\n", v.offset)
        gen_print (gen, "    push    qword [rax]\n")

    case PUSH_BOOL:
        gen_printf(gen, "    push    {}\n", v.value ? "SK_TRUE" : "SK_FALSE")

    case PUSH_BYTE:
        gen_printf(gen, "    push    [CONST{}]\n", v.index)

    case PUSH_CONST:
        if v.const.type == type_bool {
            gen_printf(gen, "    push    {}\n", v.const.value.(bool) ? "SK_TRUE" : "SK_FALSE")
        } else {
            if v.const.type == type_string {
                gen_printf(gen, "    push    CONST{}\n", v.const.index)
            } else {
                gen_printf(gen, "    push    [CONST{}]\n", v.const.index)
            }
        }

    case PUSH_FLOAT:
        gen_printf(gen, "    push    [CONST{}]\n", v.index)

    case PUSH_INT:
        gen_printf(gen, "    push    [CONST{}]\n", v.index)

    case PUSH_STRING:
        gen_printf(gen, "    push    CONST{}\n", v.index)

    case PUSH_TYPE:

    case PUSH_UINT:
        gen_printf(gen, "    push    [CONST{}]\n", v.index)

    case RETURN:
        gen_print (gen, "    mov     rax, rsp\n")
        gen_print (gen, "    mov     rsp, [ret_stack_ptr]\n")
        gen_printf(gen, "    add     rsp, {}\n", this_proc.stack_frame_size)
        gen_print (gen, "    ret\n")

    case RETURN_VALUE:
        gen_print (gen, "    mov     rax, rsp\n")
        gen_print (gen, "    mov     rsp, [ret_stack_ptr]\n")
        gen_printf(gen, "    add     rsp, {}\n", this_proc.stack_frame_size)
        gen_print (gen, "    ret\n")

    case RETURN_VALUES:
        gen_print (gen, "    mov     rax, rsp\n")
        gen_print (gen, "    mov     rsp, [ret_stack_ptr]\n")
        gen_printf(gen, "    add     rsp, {}\n", this_proc.stack_frame_size)
        gen_print (gen, "    ret\n")

    case ROTATE_LEFT:
        gen_print (gen, "    pop     rcx\n")
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rbx\n")
        gen_print (gen, "    push    rcx\n")
        gen_print (gen, "    push    rax\n")

    case ROTATE_RIGHT:
        gen_print (gen, "    pop     rcx\n")
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rcx\n")
        gen_print (gen, "    push    rax\n")
        gen_print (gen, "    push    rbx\n")

    case STORE_BIND:
        gen_print (gen, "    mov     rax, [ret_stack_ptr]\n")
        gen_print (gen, "    pop     rbx\n")
        gen_printf(gen, "    mov     [rax+{}], rbx\n", v.offset)

    case STORE_VAR:

    case SWAP:
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rbx\n")
        gen_print (gen, "    push    rax\n")

    case TUCK:
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rbx\n")
        gen_print (gen, "    push    rax\n")
        gen_print (gen, "    push    rbx\n")

    }
}

write_file :: proc(gen: ^Generator) {
    result := strings.builder_make()
    strings.write_string(&result, strings.to_string(gen.prepend))
    strings.write_string(&result, "\n")
    strings.write_string(&result, strings.to_string(gen.bss_segment))
    strings.write_string(&result, "\n")
    strings.write_string(&result, strings.to_string(gen.data_segment))
    strings.write_string(&result, "\n")
    strings.write_string(&result, strings.to_string(gen.text_segment))

    error := os2.write_entire_file(fmt.tprintf("{}.asm", output_filename), result.buf[:])
    if error != nil {
        fatalf(.Generator, "could not generate output file")
    }
}
