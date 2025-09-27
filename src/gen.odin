package main

import "core:fmt"
import "core:os/os2"
import "core:reflect"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

Generator :: struct {
    bss_segment:   strings.Builder,
    data_segment:  strings.Builder,
    text_segment:  strings.Builder,

    indent:        int,

    source:        ^strings.Builder,
    multi_results: [dynamic]string,
}

REGISTERS :: []string{
    "rax", "rbx", "rcx", "rdx", "rsi", "rdi",
    "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15",
}

string_to_bytes :: proc(s: string) -> []byte {
    result := make([dynamic]byte, 0, len(s), context.temp_allocator)

    for index := 0; index < len(s); index += 1 {
        char := s[index]
        byte_value: byte

        if char == '\\' {
            index += 1
            char = s[index]

            switch char {
            case 'a':  byte_value = 7
            case 'b':  byte_value = 8
            case 't':  byte_value = 9
            case 'n':  byte_value = 10
            case 'v':  byte_value = 11
            case 'f':  byte_value = 12
            case 'r':  byte_value = 13
            case 'e':  byte_value = 27
            case '"':  byte_value = 34
            case '\'': byte_value = 39
            case:      byte_value = byte(char)
            }
        } else {
            byte_value = byte(char)
        }

        append(&result, byte_value)
    }

    return result[:]
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
    gen.source = &gen.data_segment
    gen_print (gen, "bits 64\n")
    gen_print (gen, "default rel\n")

    gen_print (gen, "section .bss\n")
    gen_print (gen, "args_ptr:           resb 64\n")
    gen_print (gen, "ret_stack_ptr:      resb 64\n")
    gen_print (gen, "ret_stack:          resb 65535\n")
    gen_print (gen, "ret_stack_ptr_end:\n")
    if compiler.global_proc.stack_frame_size > 0 {
        gen_printf(gen, "stanczyk_static:    resb {}\n", compiler.global_proc.stack_frame_size)
    }
    gen_print (gen, "TEMP_QWORD:         resq 0\n")

    gen_print (gen, "section .rodata\n")
    gen_print (gen, "EMPTY_STRING: db \"\",0\n")
    gen_print (gen, "FORMAT_BOOL:  db \"%s\",10,0\n")
    gen_print (gen, "FORMAT_FLOAT: db \"%g\",10,0\n")
    gen_print (gen, "FORMAT_INT:   db \"%d\",10,0\n")
    gen_print (gen, "FORMAT_UINT:  db \"%u\",10,0\n")

    gen_print (gen, "TRUE_STR:     db \"true\",0\n")
    gen_print (gen, "FALSE_STR:    db \"false\",0\n")

    gen_print (gen, "; constant table starts here\n")
    for const in compiler.constants_table {
        gen_printf(gen, "CONST{}: ; ({}) {}\n", const.index, const.type.name, const.value)

        switch v in const.value {
        case bool:
            gen_printf(gen, "    db {} ; {}\n", v ? 1 : 0, v)

        case byte:
            gen_printf(gen, "    dq {}\n", v)

        case f64:
            gen_printf(gen, "    dq %.15f\n", v)

        case i64:
            gen_printf(gen, "    dq {}\n", v)

        case u64:
            gen_printf(gen, "    dq {}\n", v)

        case string:
            as_bytes := string_to_bytes(v)

            gen_printf(gen, "    dd {}\n", len(as_bytes))
            gen_print (gen, "    db ")
            for b in as_bytes {
                gen_printf(gen, "{},", b)
            }
            gen_print (gen, "0\n")
        }
    }

    gen_print (gen, "; constant table ends here\n")

    gen.source = &gen.text_segment
    gen_print (gen, "section .text\n")
    gen_print (gen, "global  _start\n")
    gen_print (gen, "extern exit\n")
    gen_print (gen, "extern strcmp\n")
    gen_print (gen, "extern printf\n")
    gen_print (gen, "extern putchar\n")
    gen_print (gen, "extern puts\n")
    gen_print (gen, "_start:\n")
    gen_print (gen, "    mov     [args_ptr], rsp\n")
    gen_print (gen, "    mov     rax, ret_stack_ptr_end\n")

    for ins in compiler.global_proc.code {
        gen_instruction(gen, compiler.global_proc, ins)
    }

    gen_print (gen, "stanczyk_user_program:\n")
    gen_print (gen, "    mov     [ret_stack_ptr], rax\n")
    gen_print (gen, "    mov     rax, rsp\n")
    gen_print (gen, "    mov     rsp, [ret_stack_ptr]\n")
    gen_printf(gen, "    call    proc{}\n", compiler.main_proc_uid)
    gen_print (gen, "    mov     [ret_stack_ptr], rsp\n")
    gen_print (gen, "    mov     rsp, rax\n")
    gen_print (gen, "    xor     rdi, rdi\n")
    gen_print (gen, "    call    exit\n")

    gen_print (gen, "; code starts here\n")

}

gen_program :: proc() {
    gen := new(Generator)
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

gen_ip_label :: proc(gen: ^Generator, this_proc: ^Procedure, ins: ^Instruction) {
    gen_printf(gen, "proc{}.ip{}:\n", this_proc.id, ins.offset)
}

gen_instruction :: proc(gen: ^Generator, this_proc: ^Procedure, ins: ^Instruction) {

    switch v in ins.variant {
    case BINARY_ADD:
        gen_ip_label(gen, this_proc, ins)

        if v.type == type_float {
            gen_print (gen, "    pop     rbx\n")
            gen_print (gen, "    pop     rax\n")
            gen_print (gen, "    movq    xmm0, rax\n")
            gen_print (gen, "    movq    xmm1, rbx\n")
            gen_print (gen, "    addsd   xmm0, xmm1\n")
            gen_print (gen, "    movsd   [TEMP_QWORD], xmm0\n")
            gen_print (gen, "    push    QWORD [TEMP_QWORD]\n")
        } else {
            gen_print (gen, "    pop     rbx\n")
            gen_print (gen, "    pop     rax\n")
            gen_print (gen, "    add     rax, rbx\n")
            gen_print (gen, "    push    rax\n")
        }

    case BINARY_DIVIDE:
        gen_ip_label(gen, this_proc, ins)

        if v.type == type_float {
            gen_print (gen, "    pop     rbx\n")
            gen_print (gen, "    pop     rax\n")
            gen_print (gen, "    movq    xmm0, rax\n")
            gen_print (gen, "    movq    xmm1, rbx\n")
            gen_print (gen, "    divsd   xmm0, xmm1\n")
            gen_print (gen, "    movsd   [TEMP_QWORD], xmm0\n")
            gen_print (gen, "    push    QWORD [TEMP_QWORD]\n")
        } else {
            gen_print (gen, "    xor     rdx, rdx\n")
            gen_print (gen, "    pop     rbx\n")
            gen_print (gen, "    pop     rax\n")
            gen_print (gen, "    div     rbx\n")
            gen_print (gen, "    push    rax\n")
        }

    case BINARY_MINUS:
        gen_ip_label(gen, this_proc, ins)

        if v.type == type_float {
            gen_print (gen, "    pop     rbx\n")
            gen_print (gen, "    pop     rax\n")
            gen_print (gen, "    movq    xmm0, rax\n")
            gen_print (gen, "    movq    xmm1, rbx\n")
            gen_print (gen, "    subsd   xmm0, xmm1\n")
            gen_print (gen, "    movsd   [TEMP_QWORD], xmm0\n")
            gen_print (gen, "    push    QWORD [TEMP_QWORD]\n")
        } else {
            gen_print (gen, "    pop     rbx\n")
            gen_print (gen, "    pop     rax\n")
            gen_print (gen, "    sub     rax, rbx\n")
            gen_print (gen, "    push    rax\n")
        }

    case BINARY_MULTIPLY:
        gen_ip_label(gen, this_proc, ins)

        if v.type == type_float {
            gen_print (gen, "    pop     rbx\n")
            gen_print (gen, "    pop     rax\n")
            gen_print (gen, "    movq    xmm0, rax\n")
            gen_print (gen, "    movq    xmm1, rbx\n")
            gen_print (gen, "    mulsd   xmm0, xmm1\n")
            gen_print (gen, "    movsd   [TEMP_QWORD], xmm0\n")
            gen_print (gen, "    push    QWORD [TEMP_QWORD]\n")
        } else {
            gen_print (gen, "    pop     rbx\n")
            gen_print (gen, "    pop     rax\n")
            gen_print (gen, "    mul     rbx\n")
            gen_print (gen, "    push    rax\n")
        }

    case BINARY_MODULO:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    xor     rdx, rdx\n")
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    div     rbx\n")
        gen_print (gen, "    push    rdx\n")

    case CAST:

    case COMPARE_EQUAL:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    xor     ecx, ecx\n")
        gen_print (gen, "    mov     edx, 1\n")

        if v.type == type_string {
            gen_print (gen, "    xor     rax, rax\n")
            gen_print (gen, "    pop     rsi\n")
            gen_print (gen, "    pop     rdi\n")
            gen_print (gen, "    call    strcmp\n")
            gen_print (gen, "    cmp     rax, 0\n")
        } else {
            gen_print (gen, "    pop     rbx\n")
            gen_print (gen, "    pop     rax\n")
            gen_print (gen, "    cmp     rax, rbx\n")
        }

        gen_print (gen, "    cmove   ecx, edx\n")
        gen_print (gen, "    push    rcx\n")

    case COMPARE_NOT_EQUAL:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    xor     ecx, ecx\n")
        gen_print (gen, "    mov     edx, 1\n")

        if v.type == type_string {
            gen_print (gen, "    xor     rax, rax\n")
            gen_print (gen, "    pop     rsi\n")
            gen_print (gen, "    pop     rdi\n")
            gen_print (gen, "    call    strcmp\n")
            gen_print (gen, "    cmp     rax, 0\n")
        } else {
            gen_print (gen, "    pop     rbx\n")
            gen_print (gen, "    pop     rax\n")
            gen_print (gen, "    cmp     rax, rbx\n")
        }

        gen_print (gen, "    cmovne  rcx, rdx\n")
        gen_print (gen, "    push    rcx\n")

    case COMPARE_GREATER:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    xor     ecx, ecx\n")
        gen_print (gen, "    mov     edx, 1\n")
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    cmp     rax, rbx\n")
        gen_print (gen, "    cmovg   rcx, rdx\n")
        gen_print (gen, "    push    rcx\n")

    case COMPARE_GREATER_EQUAL:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    xor     ecx, ecx\n")
        gen_print (gen, "    mov     edx, 1\n")
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    cmp     rax, rbx\n")
        gen_print (gen, "    cmovge  rcx, rdx\n")
        gen_print (gen, "    push    rcx\n")

    case COMPARE_LESS:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    xor     ecx, ecx\n")
        gen_print (gen, "    mov     edx, 1\n")
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    cmp     rax, rbx\n")
        gen_print (gen, "    cmovl   rcx, rdx\n")
        gen_print (gen, "    push    rcx\n")

    case COMPARE_LESS_EQUAL:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    xor     ecx, ecx\n")
        gen_print (gen, "    mov     edx, 1\n")
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    cmp     rax, rbx\n")
        gen_print (gen, "    cmovle  rcx, rdx\n")
        gen_print (gen, "    push    rcx\n")

    case DROP:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    pop     rax\n")

    case DUP:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rax\n")
        gen_print (gen, "    push    rax\n")

    case DUP_PREV:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rax\n")
        gen_print (gen, "    push    rax\n")
        gen_print (gen, "    push    rbx\n")

    case FOR_LOOP_END:
        gen_ip_label(gen, this_proc, ins)
        gen_printf(gen, "    jmp     proc{}.ip{}.start\n", this_proc.id, v.id)
        gen_printf(gen, "proc{}.ip{}.end:\n", this_proc.id, v.id)

    case FOR_LOOP_RANGE_START:
        limit_offset := v.offsets[0]
        index_offset := v.offsets[1]
        curr_value_offset := v.offsets[2]

        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    mov     rax, [ret_stack_ptr]\n")
        gen_print (gen, "    pop     rbx\n")
        gen_printf(gen, "    mov     QWORD [rax+{}], rbx\n", limit_offset)
        gen_printf(gen, "    mov     QWORD [rax+{}], 0\n",   index_offset)
        gen_print (gen, "    pop     rbx\n")
        gen_printf(gen, "    mov     QWORD [rax+{}], rbx\n", curr_value_offset)
        gen_printf(gen, "    jmp     proc{}.ip{}.loop\n", this_proc.id, v.id)
        gen_printf(gen, "proc{}.ip{}.start:\n", this_proc.id, v.id)
        gen_print (gen, "    mov     rax, [ret_stack_ptr]\n")

        // increment index
        gen_printf(gen, "    mov     rbx, [rax+{}]\n", index_offset)
        gen_print (gen, "    inc     ebx\n")
        gen_printf(gen, "    mov     QWORD [rax+{}], rbx\n", index_offset)

        // increment initial value
        gen_printf(gen, "    mov     rbx, [rax+{}]\n", curr_value_offset)
        if v.dir == .Inc {
            gen_print (gen, "    inc     ebx\n")
        } else {
            gen_print (gen, "    dec     ebx\n")
        }
        gen_printf(gen, "    mov     QWORD [rax+{}], rbx\n", curr_value_offset)

        // start loop
        gen_printf(gen, "proc{}.ip{}.loop:\n", this_proc.id, v.id)
        gen_print (gen, "    xor     ecx, ecx\n")
        gen_print (gen, "    mov     edx, 1\n")
        gen_print (gen, "    mov     rax, [ret_stack_ptr]\n")
        gen_printf(gen, "    mov     rdi, [rax+{}]\n", curr_value_offset) // value
        gen_printf(gen, "    mov     rsi, [rax+{}]\n", limit_offset) // limit
        gen_print (gen, "    cmp     rdi, rsi\n")
        if v.dir == .Inc {
            gen_print (gen, "    cmovl   ecx, edx\n")
        } else {
            gen_print (gen, "    cmovg   ecx, edx\n")
        }
        gen_print (gen, "    test    ecx, ecx\n")
        gen_printf(gen, "    jz      proc{}.ip{}.end\n", this_proc.id, v.id)

    case IDENTIFIER:

    case IF_ELSE_JUMP:
        gen_printf(gen, "    jmp     proc{}.ip{}.end\n", this_proc.id, v.id)
        gen_ip_label(gen, this_proc, ins)
        gen_printf(gen, "proc{}.ip{}.else:\n", this_proc.id, v.id)

    case IF_END:
        gen_ip_label(gen, this_proc, ins)
        gen_printf(gen, "proc{}.ip{}.end:\n", this_proc.id, v.id)

    case IF_FALSE_JUMP:
        jump_to_else := v.scope.kind == .Branch_Else

        gen_ip_label(gen, this_proc, ins)
        gen_print  (gen, "    pop    rax\n")
        gen_print  (gen, "    test   rax, rax\n")
        gen_printf (
            gen, "    jz     proc{}.ip{}.{}\n",  this_proc.id, v.id,
            jump_to_else ? "else" : "end",
        )

    case INVOKE_PROC:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    mov     rax, rsp\n")
        gen_print (gen, "    mov     rsp, [ret_stack_ptr]\n")
        gen_printf(gen, "    call    proc{} ; {}\n", v.procedure.id, v.procedure.name)
        gen_print (gen, "    mov     [ret_stack_ptr], rsp\n")
        gen_print (gen, "    mov     rsp, rax\n")

    case LEN:
        gen_ip_label(gen, this_proc, ins)

        if v.type != type_string {
            unimplemented()
        }

        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    sub     eax, 4\n")
        gen_print (gen, "    push    QWORD [rax]\n")

    case NIP:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rbx\n")

    case OVER:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rax\n")
        gen_print (gen, "    push    rbx\n")
        gen_print (gen, "    push    rax\n")

    case PRINT:
        gen_ip_label(gen, this_proc, ins)

        #partial switch variant in v.type.variant {
        case Type_Basic:
            switch variant.kind {
            case .Bool:
                gen_print(gen, "    mov     rdx, TRUE_STR\n")
                gen_print(gen, "    mov     rdi, FALSE_STR\n")
                gen_print(gen, "    pop     rbx\n")
                gen_print(gen, "    cmp     rbx, 1\n")
                gen_print(gen, "    cmove   rdi, rdx\n")
                gen_print(gen, "    call    puts\n")
            case .Byte:
                gen_print(gen, "    xor     edi, edi\n")
                gen_print(gen, "    pop     rdi\n")
                gen_print(gen, "    call    putchar\n")
                gen_print(gen, "    mov     edi, 10\n")
                gen_print(gen, "    call    putchar\n")
            case .Float:
                gen_print(gen, "    pop     rbx\n")
                gen_print(gen, "    movq    xmm0, rbx\n")
                gen_print(gen, "    mov     eax, 1\n")
                gen_print(gen, "    mov     edi, FORMAT_FLOAT\n")
                gen_print(gen, "    call    printf\n")
            case .Int:
                gen_print(gen, "    pop     rsi\n")
                gen_print(gen, "    xor     eax, eax\n")
                gen_print(gen, "    mov     edi, FORMAT_INT\n")
                gen_print(gen, "    call    printf\n")
            case .String:
                gen_print(gen, "    pop     rdi\n")
                gen_print(gen, "    call    puts\n")
            case .Uint:
                gen_print(gen, "    pop     rsi\n")
                gen_print(gen, "    xor     eax, eax\n")
                gen_print(gen, "    mov     edi, FORMAT_UINT\n")
                gen_print(gen, "    call    printf\n")
            }
        }

    case PUSH_BIND:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    mov     rax, [ret_stack_ptr]\n")
        gen_printf(gen, "    add     rax, {}\n", v.offset)
        gen_print (gen, "    push    QWORD [rax]\n")

    case PUSH_BOOL:
        gen_ip_label(gen, this_proc, ins)
        gen_printf(gen, "    mov     rax, {}\n", v.value ? 1 : 0)
        gen_print (gen, "    push    rax\n")

    case PUSH_BYTE:
        gen_ip_label(gen, this_proc, ins)
        gen_printf(gen, "    push    {}\n", v.value)

    case PUSH_CONST:
        gen_ip_label(gen, this_proc, ins)

        switch value in v.const.value {
        case bool:
            gen_printf(gen, "    mov     rax, {}\n", value ? 1 : 0)
            gen_print (gen, "    push    rax\n")
        case f64:
            gen_printf(gen, "    mov     rax, [CONST{}]\n", v.const.index)
            gen_print (gen, "    push    rax\n")
        case i64:
            gen_printf(gen, "    push    {}\n", value)
        case string:
            gen_printf(gen, "    lea     rax, [CONST{}]\n", v.const.index)
            gen_print (gen, "    add     rax, 4\n")
            gen_print (gen, "    push    rax\n")
        case u64:
            gen_printf(gen, "    push    {}\n", value)
        case byte:
            gen_printf(gen, "    push    {}\n", value)
        }

    case PUSH_FLOAT:
        gen_ip_label(gen, this_proc, ins)
        gen_printf(gen, "    mov     rax, [CONST{}]\n", v.index)
        gen_print (gen, "    push    rax\n")

    case PUSH_INT:
        gen_ip_label(gen, this_proc, ins)
        gen_printf(gen, "    push    {}\n", v.value)

    case PUSH_STRING:
        gen_ip_label(gen, this_proc, ins)
        gen_printf(gen, "    lea     rax, [CONST{}]\n", v.index)
        gen_print (gen, "    add     rax, 4\n")
        gen_print (gen, "    push    rax\n")

    case PUSH_TYPE:

    case PUSH_UINT:
        gen_ip_label(gen, this_proc, ins)
        gen_printf(gen, "    push    {}\n", v.value)

    case PUSH_VAR_GLOBAL:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    lea     rax, [stanczyk_static]\n")
        gen_printf(gen, "    add     rax, {}\n", v.offset)

        if !ins.quoted {
            gen_print (gen, "    mov     rax, [rax]\n")
        }

        gen_print(gen, "    push    rax\n")

    case PUSH_VAR_LOCAL:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    mov     rax, [ret_stack_ptr]\n")
        gen_printf(gen, "    add     rax, {}\n", v.offset)

        if !ins.quoted {
            gen_print (gen, "    mov     rax, [rax]\n")
        }

        gen_print(gen, "    push    rax\n")

    case RETURN:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    mov     rax, rsp\n")
        gen_print (gen, "    mov     rsp, [ret_stack_ptr]\n")
        gen_printf(gen, "    add     rsp, {}\n", this_proc.stack_frame_size)
        gen_print (gen, "    ret\n")

    case RETURN_VALUE:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    mov     rax, rsp\n")
        gen_print (gen, "    mov     rsp, [ret_stack_ptr]\n")
        gen_printf(gen, "    add     rsp, {}\n", this_proc.stack_frame_size)
        gen_print (gen, "    ret\n")

    case RETURN_VALUES:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    mov     rax, rsp\n")
        gen_print (gen, "    mov     rsp, [ret_stack_ptr]\n")
        gen_printf(gen, "    add     rsp, {}\n", this_proc.stack_frame_size)
        gen_print (gen, "    ret\n")

    case ROTATE_LEFT:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    pop     rcx\n")
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rbx\n")
        gen_print (gen, "    push    rcx\n")
        gen_print (gen, "    push    rax\n")

    case ROTATE_RIGHT:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    pop     rcx\n")
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rcx\n")
        gen_print (gen, "    push    rax\n")
        gen_print (gen, "    push    rbx\n")

    case SET:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    mov     [rbx], rax\n")

    case STORE_BIND:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    mov     rax, [ret_stack_ptr]\n")
        gen_print (gen, "    pop     rbx\n")
        gen_printf(gen, "    mov     [rax+{}], rbx\n", v.offset)

    case STORE_VAR_GLOBAL:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    lea     rax, [stanczyk_static]\n")
        gen_print (gen, "    pop     rbx\n")
        gen_printf(gen, "    mov     [rax+{}], rbx\n", v.offset)

    case STORE_VAR_LOCAL:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    mov     rax, [ret_stack_ptr]\n")
        gen_print (gen, "    pop     rbx\n")
        gen_printf(gen, "    mov     [rax+{}], rbx\n", v.offset)

    case SWAP:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rbx\n")
        gen_print (gen, "    push    rax\n")

    case TUCK:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    pop     rbx\n")
        gen_print (gen, "    pop     rax\n")
        gen_print (gen, "    push    rbx\n")
        gen_print (gen, "    push    rax\n")
        gen_print (gen, "    push    rbx\n")

    }
}

write_file :: proc(gen: ^Generator) {
    result := strings.builder_make()
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
