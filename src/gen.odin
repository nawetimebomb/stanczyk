package main

import "core:fmt"
import "core:os/os2"
import "core:reflect"
import "core:slice"
import "core:strconv"
import "core:strings"

Generator :: struct {
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
    gen.source = &gen.data_segment
    gen_print (gen, ".section .data\n")
    gen_print (gen, "args_ptr:           .space 64\n")
    gen_print (gen, "ret_stack_ptr:      .space 64\n")
    gen_print (gen, "ret_stack:          .space 65535\n")
    gen_print (gen, "ret_stack_ptr_end:\n")
    if compiler.global_proc.stack_frame_size > 0 {
        gen_printf(gen, "stanczyk_static:    .space {}\n", compiler.global_proc.stack_frame_size)
    }
    gen_print (gen, "TEMP_QWORD:         .double 0\n")

    gen_print (gen, ".section .rodata\n")
    gen_print (gen, "EMPTY_STRING: .asciz \"\"\n")
    gen_print (gen, "FORMAT_BOOL:  .asciz \"%s\\n\"\n")
    gen_print (gen, "FORMAT_FLOAT: .asciz \"%g\\n\"\n")
    gen_print (gen, "FORMAT_INT:   .asciz \"%d\\n\"\n")
    gen_print (gen, "FORMAT_UINT:  .asciz \"%u\\n\"\n")

    gen_print (gen, "TRUE_STR:     .asciz \"true\"\n")
    gen_print (gen, "FALSE_STR:    .asciz \"false\"\n")
    gen_print (gen, "SK_TRUE:      .byte 1\n")
    gen_print (gen, "SK_FALSE:     .byte 0\n")

    for const in compiler.constants_table {
        gen_printf(gen, "CONST{}: ", const.index)

        switch v in const.value {
        case bool:
            gen_printf(gen, ".byte {} # {}\n", v ? 1 : 0, v)

        case byte:
            gen_printf(gen, ".quad {}\n", v)

        case f64:
            gen_printf(gen, ".double %.10f\n", v)

        case i64:
            gen_printf(gen, ".quad {}\n", v)

        case u64:
            gen_printf(gen, ".quad {}\n", v)

        case string:
            gen_printf(gen, ".asciz \"{}\"\n", v)
        }
    }

    gen.source = &gen.text_segment
    gen_print (gen, ".section .text\n")
    gen_print (gen, ".global  main\n")
    gen_print (gen, "main:\n")
    gen_print (gen, "    movq    %rsp, (args_ptr)\n")
    gen_print (gen, "    movq    $ret_stack_ptr_end, %rax\n")

    for ins in compiler.global_proc.code {
        gen_instruction(gen, compiler.global_proc, ins)
    }

    gen_print (gen, "stanczyk_user_program:\n")
    gen_print (gen, "    movq    %rax, (ret_stack_ptr)\n")
    gen_print (gen, "    movq    %rsp, %rax\n")
    gen_print (gen, "    movq    (ret_stack_ptr), %rsp\n")
    gen_printf(gen, "    call    proc{}\n", compiler.main_proc_uid)
    gen_print (gen, "    movq    %rsp, (ret_stack_ptr)\n")
    gen_print (gen, "    mov     %rax, %rsp\n")
    gen_print (gen, "    xor     %rdi, %rdi\n")
    gen_print (gen, "    call    exit\n")

    gen_print (gen, "# code starts here\n")

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

    gen_print (gen, "# code ends here\n")

    write_file(gen)
}

gen_procedure :: proc(gen: ^Generator, procedure: ^Procedure) {
    gen_printf(gen, "proc{}: # {}\n", procedure.id, procedure.name)
    gen_printf(gen, "    subq    ${}, %%rsp\n", procedure.stack_frame_size)
    gen_print (gen, "    movq    %rsp, (ret_stack_ptr)\n")
    gen_print (gen, "    movq    %rax, %rsp\n")

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
            gen_print (gen, "    popq    %rbx\n")
            gen_print (gen, "    popq    %rax\n")
            gen_print (gen, "    movq    %rax, %xmm0\n")
            gen_print (gen, "    movq    %rax, %xmm1\n")
            gen_print (gen, "    addsd   %xmm1, %xmm0\n")
            gen_print (gen, "    movsd   %xmm0, (TEMP_QWORD)\n")
            gen_print (gen, "    pushq   (TEMP_QWORD)\n")
        } else {
            gen_print (gen, "    popq    %rbx\n")
            gen_print (gen, "    popq    %rax\n")
            gen_print (gen, "    addq    %rbx, %rax\n")
            gen_print (gen, "    pushq   %rax\n")
        }

    case BINARY_DIVIDE:
        gen_ip_label(gen, this_proc, ins)

        if v.type == type_float {
            gen_print (gen, "    popq    %rbx\n")
            gen_print (gen, "    popq    %rax\n")
            gen_print (gen, "    movq    %rax, %xmm0\n")
            gen_print (gen, "    movq    %rax, %xmm1\n")
            gen_print (gen, "    divsd   %xmm1, %xmm0\n")
            gen_print (gen, "    movsd   %xmm0, (TEMP_QWORD)\n")
            gen_print (gen, "    pushq   (TEMP_QWORD)\n")
        } else {
            gen_print (gen, "    xorq    %rdx, %rdx\n")
            gen_print (gen, "    popq    %rbx\n")
            gen_print (gen, "    popq    %rax\n")
            gen_print (gen, "    divq    %rbx\n")
            gen_print (gen, "    pushq   %rax\n")
        }

    case BINARY_MINUS:
        gen_ip_label(gen, this_proc, ins)

        if v.type == type_float {
            gen_print (gen, "    popq    %rbx\n")
            gen_print (gen, "    popq    %rax\n")
            gen_print (gen, "    movq    %rax, %xmm0\n")
            gen_print (gen, "    movq    %rax, %xmm1\n")
            gen_print (gen, "    subsd   %xmm1, %xmm0\n")
            gen_print (gen, "    movsd   %xmm0, (TEMP_QWORD)\n")
            gen_print (gen, "    pushq   (TEMP_QWORD)\n")
        } else {
            gen_print (gen, "    popq    %rbx\n")
            gen_print (gen, "    popq    %rax\n")
            gen_print (gen, "    subq    %rbx, %rax\n")
            gen_print (gen, "    pushq   %rax\n")
        }

    case BINARY_MULTIPLY:
        gen_ip_label(gen, this_proc, ins)

        if v.type == type_float {
            gen_print (gen, "    popq    %rbx\n")
            gen_print (gen, "    popq    %rax\n")
            gen_print (gen, "    movq    %rax, %xmm0\n")
            gen_print (gen, "    movq    %rax, %xmm1\n")
            gen_print (gen, "    mulsd   %xmm1, %xmm0\n")
            gen_print (gen, "    movsd   %xmm0, (TEMP_QWORD)\n")
            gen_print (gen, "    pushq   (TEMP_QWORD)\n")
        } else {
            gen_print (gen, "    popq    %rbx\n")
            gen_print (gen, "    popq    %rax\n")
            gen_print (gen, "    mulq    %rbx\n")
            gen_print (gen, "    pushq   %rax\n")
        }

    case BINARY_MODULO:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    xorq    %rdx, %rdx\n")
        gen_print (gen, "    popq    %rbx\n")
        gen_print (gen, "    popq    %rax\n")
        gen_print (gen, "    divq    %rbx\n")
        gen_print (gen, "    pushq   %rdx\n")

    case CAST:

    case COMPARE_EQUAL:
        gen_ip_label(gen, this_proc, ins)

        if v.type == type_string {
            gen_print (gen, "    movq    $SK_FALSE, %rcx\n")
            gen_print (gen, "    movq    $SK_TRUE, %rdx\n")
            gen_print (gen, "    xorq    %rax, %rax\n")
            gen_print (gen, "    popq    %rsi\n")
            gen_print (gen, "    popq    %rdi\n")
            gen_print (gen, "    call    strcmp\n")
            gen_print (gen, "    cmpq    $0, %rax\n")
            gen_print (gen, "    cmoveq  %rdx, %rcx\n")
            gen_print (gen, "    pushq   %rcx\n")
        } else {
            gen_print (gen, "    movq    $SK_FALSE, %rcx\n")
            gen_print (gen, "    movq    $SK_TRUE, %rdx\n")
            gen_print (gen, "    popq    %rbx\n")
            gen_print (gen, "    popq    %rax\n")
            gen_print (gen, "    cmpq    %rbx, %rax\n")
            gen_print (gen, "    cmoveq  %rdx, %rcx\n")
            gen_print (gen, "    pushq   %rcx\n")
        }

    case COMPARE_NOT_EQUAL:
        gen_ip_label(gen, this_proc, ins)

        if v.type == type_string {
            gen_print (gen, "    movq    $SK_FALSE, %rcx\n")
            gen_print (gen, "    movq    $SK_TRUE, %rdx\n")
            gen_print (gen, "    xorq    %rax, %rax\n")
            gen_print (gen, "    popq    %rsi\n")
            gen_print (gen, "    popq    %rdi\n")
            gen_print (gen, "    call    strcmp\n")
            gen_print (gen, "    cmpq    $0, %rax\n")
            gen_print (gen, "    cmovneq %rdx, %rcx\n")
            gen_print (gen, "    pushq   %rcx\n")
        } else {
            gen_print (gen, "    movq    $SK_FALSE, %rcx\n")
            gen_print (gen, "    movq    $SK_TRUE, %rdx\n")
            gen_print (gen, "    popq    %rbx\n")
            gen_print (gen, "    popq    %rax\n")
            gen_print (gen, "    cmpq    %rbx, %rax\n")
            gen_print (gen, "    cmovneq %rdx, %rcx\n")
            gen_print (gen, "    pushq   %rcx\n")
        }

    case COMPARE_GREATER:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    movq    $SK_FALSE, %rcx\n")
        gen_print (gen, "    movq    $SK_TRUE, %rdx\n")
        gen_print (gen, "    popq    %rbx\n")
        gen_print (gen, "    popq    %rax\n")
        gen_print (gen, "    cmpq    %rbx, %rax\n")
        gen_print (gen, "    cmovgq  %rdx, %rcx\n")
        gen_print (gen, "    pushq   %rcx\n")

    case COMPARE_GREATER_EQUAL:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    movq    $SK_FALSE, %rcx\n")
        gen_print (gen, "    movq    $SK_TRUE, %rdx\n")
        gen_print (gen, "    popq    %rbx\n")
        gen_print (gen, "    popq    %rax\n")
        gen_print (gen, "    cmpq    %rbx, %rax\n")
        gen_print (gen, "    cmovgeq %rdx, %rcx\n")
        gen_print (gen, "    pushq   %rcx\n")

    case COMPARE_LESS:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    movq    $SK_FALSE, %rcx\n")
        gen_print (gen, "    movq    $SK_TRUE, %rdx\n")
        gen_print (gen, "    popq    %rbx\n")
        gen_print (gen, "    popq    %rax\n")
        gen_print (gen, "    cmpq    %rbx, %rax\n")
        gen_print (gen, "    cmovl   %rdx, %rcx\n")
        gen_print (gen, "    pushq   %rcx\n")

    case COMPARE_LESS_EQUAL:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    movq    $SK_FALSE, %rcx\n")
        gen_print (gen, "    movq    $SK_TRUE, %rdx\n")
        gen_print (gen, "    popq    %rbx\n")
        gen_print (gen, "    popq    %rax\n")
        gen_print (gen, "    cmpq    %rbx, %rax\n")
        gen_print (gen, "    cmovleq %rdx, %rcx\n")
        gen_print (gen, "    pushq   %rcx\n")

    case DROP:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    popq    %rax\n")

    case DUP:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    popq    %rax\n")
        gen_print (gen, "    pushq   %rax\n")
        gen_print (gen, "    pushq   %rax\n")

    case DUP_PREV:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    popq    %rbx\n")
        gen_print (gen, "    popq    %rax\n")
        gen_print (gen, "    pushq   %rax\n")
        gen_print (gen, "    pushq   %rax\n")
        gen_print (gen, "    pushq   %rbx\n")

    case IDENTIFIER:

    case IF_ELSE_JUMP:

    case IF_END:

    case IF_FALSE_JUMP:

    case INVOKE_PROC:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    movq    %rsp, %rax\n")
        gen_print (gen, "    movq    (ret_stack_ptr), %rsp\n")
        gen_printf(gen, "    call    proc{} # {}\n", v.procedure.id, v.procedure.name)
        gen_print (gen, "    movq    %rsp, (ret_stack_ptr)\n")
        gen_print (gen, "    movq    %rax, %rsp\n")

    case NIP:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    popq    %rbx\n")
        gen_print (gen, "    popq    %rax\n")
        gen_print (gen, "    pushq   %rbx\n")

    case OVER:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    popq    %rbx\n")
        gen_print (gen, "    popq    %rax\n")
        gen_print (gen, "    pushq   %rax\n")
        gen_print (gen, "    pushq   %rbx\n")
        gen_print (gen, "    pushq   %rax\n")

    case PRINT:
        gen_ip_label(gen, this_proc, ins)

        #partial switch variant in v.type.variant {
        case Type_Basic:
            switch variant.kind {
            case .Bool:
                gen_print(gen, "    movq    $TRUE_STR, %rdx\n")
                gen_print(gen, "    movq    $FALSE_STR, %rsi\n")
                gen_print(gen, "    xorq    %rbx, %rbx\n")
                gen_print(gen, "    popq    %rbx\n")
                gen_print(gen, "    cmpq    $SK_TRUE, %rbx\n")
                gen_print(gen, "    cmoveq  %rdx, %rsi\n")
                gen_print(gen, "    xorq    %rax, %rax\n")
                gen_print(gen, "    movq    $FORMAT_BOOL, %rdi\n")
                gen_print(gen, "    call    printf\n")
            case .Byte:
                gen_print(gen, "    xorq    %rdi, %rdi\n")
                gen_print(gen, "    popq    %rdi\n")
                gen_print(gen, "    call    putchar\n")
                gen_print(gen, "    movq    $10, %rdi\n")
                gen_print(gen, "    call    putchar\n")
            case .Float:
                gen_print(gen, "    popq    %rbx\n")
                gen_print(gen, "    movq    %rbx, %xmm0\n")
                gen_print(gen, "    movq    $1, %rax\n")
                gen_print(gen, "    movq    $FORMAT_FLOAT, %rdi\n")
                gen_print(gen, "    call    printf\n")
            case .Int:
                gen_print(gen, "    popq    %rsi\n")
                gen_print(gen, "    xorq    %rax, %rax\n")
                gen_print(gen, "    movq    $FORMAT_INT, %rdi\n")
                gen_print(gen, "    call    printf\n")
            case .String:
                gen_print(gen, "    popq    %rdi\n")
                gen_print(gen, "    call    puts\n")
            case .Uint:
                gen_print(gen, "    popq    %rsi\n")
                gen_print(gen, "    xorq    %rax, %rax\n")
                gen_print(gen, "    movq    $FORMAT_UINT, %rdi\n")
                gen_print(gen, "    call    printf\n")
            }
        }

    case PUSH_BIND:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    movq    (ret_stack_ptr), %rax\n")
        gen_printf(gen, "    addq    ${}, %%rax\n", v.offset)
        gen_print (gen, "    pushq   (%rax)\n")

    case PUSH_BOOL:
        gen_ip_label(gen, this_proc, ins)
        gen_printf(gen, "    pushq   ${}\n", v.value ? "SK_TRUE" : "SK_FALSE")

    case PUSH_BYTE:
        gen_ip_label(gen, this_proc, ins)
        gen_printf(gen, "    pushq   ${}\n", v.value)

    case PUSH_CONST:
        gen_ip_label(gen, this_proc, ins)

        switch value in v.const.value {
        case bool:   gen_printf(gen, "    pushq   ${}\n", value ? "SK_TRUE" : "SK_FALSE")
        case f64:    gen_printf(gen, "    pushq   (CONST{})\n", v.const.index)
        case i64:    gen_printf(gen, "    pushq   ${}\n", value)
        case string: gen_printf(gen, "    pushq   $CONST{}\n", v.const.index)
        case u64:    gen_printf(gen, "    pushq   ${}\n", value)
        case byte:   gen_printf(gen, "    pushq   ${}\n", value)
        }

    case PUSH_FLOAT:
        gen_ip_label(gen, this_proc, ins)
        gen_printf(gen, "    pushq   (CONST{})\n", v.index)

    case PUSH_INT:
        gen_ip_label(gen, this_proc, ins)
        gen_printf(gen, "    pushq   ${}\n", v.value)

    case PUSH_STRING:
        gen_ip_label(gen, this_proc, ins)
        gen_printf(gen, "    pushq   $CONST{}\n", v.index)

    case PUSH_TYPE:

    case PUSH_UINT:
        gen_ip_label(gen, this_proc, ins)
        gen_printf(gen, "    pushq   ${}\n", v.value)

    case PUSH_VAR_GLOBAL:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    movq    $stanczyk_static, %rax\n")
        gen_printf(gen, "    addq    ${}, %%rax\n", v.offset)

        if ins.quoted {
            gen_print (gen, "    pushq   %rax\n")
        } else {
            gen_print (gen, "    pushq   (%rax)\n")
        }

    case PUSH_VAR_LOCAL:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    movq    (ret_stack_ptr), %rax\n")
        gen_printf(gen, "    addq    ${}, %%rax\n", v.offset)
        if ins.quoted {
            gen_print (gen, "    pushq   %rax\n")
        } else {
            gen_print (gen, "    pushq   (%rax)\n")
        }

    case RETURN:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    movq    %rsp, %rax\n")
        gen_print (gen, "    movq    (ret_stack_ptr), %rsp\n")
        gen_printf(gen, "    addq    ${}, %%rsp\n", this_proc.stack_frame_size)
        gen_print (gen, "    ret\n")

    case RETURN_VALUE:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    movq    %rsp, %rax\n")
        gen_print (gen, "    movq    (ret_stack_ptr), %rsp\n")
        gen_printf(gen, "    addq    ${}, %%rsp\n", this_proc.stack_frame_size)
        gen_print (gen, "    ret\n")

    case RETURN_VALUES:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    movq    %rsp, %rax\n")
        gen_print (gen, "    movq    (ret_stack_ptr), %rsp\n")
        gen_printf(gen, "    addq    ${}, %%rsp\n", this_proc.stack_frame_size)
        gen_print (gen, "    ret\n")

    case ROTATE_LEFT:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    popq    %rcx\n")
        gen_print (gen, "    popq    %rbx\n")
        gen_print (gen, "    popq    %rax\n")
        gen_print (gen, "    pushq   %rbx\n")
        gen_print (gen, "    pushq   %rcx\n")
        gen_print (gen, "    pushq   %rax\n")

    case ROTATE_RIGHT:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    popq    %rcx\n")
        gen_print (gen, "    popq    %rbx\n")
        gen_print (gen, "    popq    %rax\n")
        gen_print (gen, "    pushq   %rcx\n")
        gen_print (gen, "    pushq   %rax\n")
        gen_print (gen, "    pushq   %rbx\n")

    case SET:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    popq    %rbx\n")
        gen_print (gen, "    popq    %rax\n")
        gen_print (gen, "    movq    %rax, (%rbx)\n")

    case STORE_BIND:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    movq    (ret_stack_ptr), %rax\n")
        gen_print (gen, "    popq    %rbx\n")
        gen_printf(gen, "    movq    %%rbx, {}(%%rax)\n", v.offset)

    case STORE_VAR_GLOBAL:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    movq    $stanczyk_static, %rax\n")
        gen_print (gen, "    popq    %rbx\n")
        gen_printf(gen, "    movq    %%rbx, {}(%%rax)\n", v.offset)

    case STORE_VAR_LOCAL:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    movq    (ret_stack_ptr), %rax\n")
        gen_print (gen, "    popq    %rbx\n")
        gen_printf(gen, "    movq    %%rbx, {}(%%rax)\n", v.offset)

    case SWAP:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    popq    %rbx\n")
        gen_print (gen, "    popq    %rax\n")
        gen_print (gen, "    pushq   %rbx\n")
        gen_print (gen, "    pushq   %rax\n")

    case TUCK:
        gen_ip_label(gen, this_proc, ins)
        gen_print (gen, "    popq    %rbx\n")
        gen_print (gen, "    popq    %rax\n")
        gen_print (gen, "    pushq   %rbx\n")
        gen_print (gen, "    pushq   %rax\n")
        gen_print (gen, "    pushq   %rbx\n")

    }
}

write_file :: proc(gen: ^Generator) {
    result := strings.builder_make()
    strings.write_string(&result, strings.to_string(gen.bss_segment))
    strings.write_string(&result, "\n")
    strings.write_string(&result, strings.to_string(gen.data_segment))
    strings.write_string(&result, "\n")
    strings.write_string(&result, strings.to_string(gen.text_segment))

    error := os2.write_entire_file(fmt.tprintf("{}.S", output_filename), result.buf[:])
    if error != nil {
        fatalf(.Generator, "could not generate output file")
    }
}
