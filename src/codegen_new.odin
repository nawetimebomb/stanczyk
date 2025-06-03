package main

import "core:fmt"
import "core:os"
import "core:strings"

Generator :: struct {
    prepend: strings.Builder,

    code: strings.Builder,
    data: strings.Builder,

    global_ip: uint,
    main_func_address: uint,
}

gen: Generator

init_generator :: proc() {
    gen.prepend = strings.builder_make()
    gen.code = strings.builder_make()
    gen.data = strings.builder_make()
}

get_global_address :: proc() -> (address: uint) {
    address = gen.global_ip
    gen.global_ip += 1
    return
}

get_local_address :: proc(f: ^Function) -> (address: uint) {
    address = f.local_ip
    f.local_ip += 1
    return
}

write :: proc(s: ^strings.Builder, format: string, args: ..any) {
    fmt.sbprintf(s, format, ..args)
}

writeln :: proc(s: ^strings.Builder, format: string, args: ..any) {
    write(s, format, ..args)
    write(s, "\n")
}

writemeta :: proc(format: string, args: ..any) {
    writeln(&gen.prepend, format, ..args)
}

writecode :: proc(format: string, args: ..any) {
    writeln(&gen.code, format, ..args)
}

writedata :: proc(format: string, args: ..any) {
    writeln(&gen.data, format, ..args)
}

gen_program :: proc() {
    gen_bootstrap()

    for f in functions {
        if f.called {
            gen_function(f)
        }
    }

    gen_compilation_unit()
}

gen_bootstrap :: proc() {
    // PREPEND BEGINS HERE
    writemeta("format ELF64")
    writemeta("public _start")
    writemeta("extrn write")
    writemeta("extrn printf")
    // PREPEND ENDS HERE

    // CODE BEGINS HERE
    writecode("section '.text' executable")
    writecode("print_number:")
    writecode("    mov r9, -3689348814741910323")
    writecode("    sub rsp, 40")
    writecode("    mov BYTE [rsp+31], 10")
    writecode("    lea rcx, [rsp+30]")
    writecode(".convert_loop:")
    writecode("    mov rax, rdi")
    writecode("    lea r8, [rsp+32]")
    writecode("    mul r9")
    writecode("    mov rax, rdi")
    writecode("    sub r8, rcx")
    writecode("    shr rdx, 3")
    writecode("    lea rsi, [rdx+rdx*4]")
    writecode("    add rsi, rsi")
    writecode("    sub rax, rsi")
    writecode("    add eax, 48")
    writecode("    mov BYTE [rcx], al")
    writecode("    mov rax, rdi")
    writecode("    mov rdi, rdx")
    writecode("    mov rdx, rcx")
    writecode("    sub rcx, 1")
    writecode("    cmp rax, 9")
    writecode("    ja  .convert_loop")
    writecode("")
    writecode("    lea rax, [rsp+32]")
    writecode("    mov edi, 1")
    writecode("    sub rdx, rax")
    writecode("    xor eax, eax")
    writecode("    lea rsi, [rsp+32+rdx]")
    writecode("    mov rdx, r8")
    writecode("    mov rax, 1")
    writecode("    syscall")
    writecode("    add rsp, 40")
    writecode("    ret")
    writecode("_start:")
    writecode("    mov [args_ptr], rsp")
    writecode("    mov rax, ret_stack_ptr_end")
    writecode("    mov [ret_stack_ptr], rax")
    writecode("    mov rax, rsp")
    writecode("    mov rsp, [ret_stack_ptr]")
    writecode("    call fn{}", gen.main_func_address)
    writecode("    mov [ret_stack_ptr], rsp")
    writecode("    mov rsp, rax")
    writecode("    xor rdi, rdi")
    writecode("    mov rax, 60")
    writecode("    syscall")
    writecode(";; user program definitions starts here")
    // CODE ENDS HERE

    // DATA BEGINS HERE
    writedata("section '.data' writeable")
    writedata("args_ptr: rq 1")
    writedata("ret_stack_ptr: rq 1")
    writedata("ret_stack: rb 65535")
    writedata("ret_stack_ptr_end:")
    // TODO: Calculate static memory needed
    writedata("stanczyk_static: rb {}", 1)
    writedata(`FMT_INT: db 37,100,10,0`)
    for key, value in strings_table {
        writedata("str_{}: db {} ; {}", value, gen_ascii(key), escaped(key))
    }
    // DATA ENDS HERE
}

gen_function :: proc(f: Function) {
    name := f.entity.name
    pos := f.entity.pos
    function_ip := f.entity.address
    bindsCount := 0
    writecode("fn{}:", function_ip)
    writecode(";; start fn {} ({}:{}:{})", name, pos.filename, pos.line, pos.column)
    //writecode("    sub rsp, {}", f.local_memory)  // TODO: calculate local memory
    writecode("    mov [ret_stack_ptr], rsp")
    writecode("    mov rsp, rax")

    for c in f.code {
        code_ip := c.address
        writecode(
            ".ip{}: ;; {} ({}:{}:{})", code_ip,
            bytecode_to_string(c), c.filename, c.line, c.column,
        )

        switch v in c.variant {
        case Push_Bool:
            writecode("    mov rax, {}", v.val ? 1 : 0)
            writecode("    push rax")
        case Push_Bound:
            writecode("    mov rax, [ret_stack_ptr]")
            writecode("    add rax, {}", v.val * 8)
            writecode("    push QWORD [rax]")
        case Push_Bound_Pointer:
            writecode("    mov rax, [ret_stack_ptr]")
            writecode("    add rax, {}", v.val * 8)
            writecode("    push rax")
        case Push_Byte:
            writecode("    mov rax, {}", int(v.val))
            writecode("    push rax")
        case Push_Cstring:
            writecode("    mov rax, str_{0}", v.val)
            writecode("    push rax")
            writecode("    mov rax, {}", v.length)
            writecode("    push rax")
        case Push_Int:
            writecode("    mov rax, {}", v.val)
            writecode("    push rax")
        case Push_String:
            writecode("    mov rax, str_{0}", v.val)
            writecode("    push rax")
        case Push_Var_Global:
        case Push_Var_Global_Pointer:
        case Push_Var_Local:
        case Push_Var_Local_Pointer:

        case Get:
            writecode("    pop rax")
            writecode("    xor rbx, rbx")
            writecode("    mov rbx, [rax]")
            writecode("    push rbx")
        case Get_Byte:
            writecode("    pop rbx")
            writecode("    pop rax")
            writecode("    add rbx, rax")
            writecode("    xor rcx, rcx")
            writecode("    mov cl, [rbx]")
            writecode("    push rcx")
        case Set:
            writecode("    pop rax")
            writecode("    pop rbx")
            writecode("    mov [rax], rbx")
        case Set_Byte:
            writecode("    pop rax")
            writecode("    pop rbx")
            writecode("    mov [rax], bl")
        case Add:
            writecode("    pop rbx")
            writecode("    pop rax")
            writecode("    add rax, rbx")
            writecode("    push rax")
        case Divide:
            writecode("    xor rdx, rdx")
            writecode("    pop rbx")
            writecode("    pop rax")
            writecode("    div rbx")
            writecode("    push rax")
        case Modulo:
            writecode("    xor rdx, rdx")
            writecode("    pop rbx")
            writecode("    pop rax")
            writecode("    div rbx")
            writecode("    push rdx")
        case Multiply:
            writecode("    pop rbx")
            writecode("    pop rax")
            writecode("    mul rbx")
            writecode("    push rax")
        case Substract:
            writecode("    pop rbx")
            writecode("    pop rax")
            writecode("    sub rax, rbx")
            writecode("    push rax")

        case Equal:
            writecode("    xor rcx, rcx")
            writecode("    mov rdx, 1")
            writecode("    pop rbx")
            writecode("    pop rax")
            writecode("    cmp rax, rbx")
            writecode("    cmove rcx, rdx")
            writecode("    push rcx")
        case Greater:
            writecode("    xor rcx, rcx")
            writecode("    mov rdx, 1")
            writecode("    pop rbx")
            writecode("    pop rax")
            writecode("    cmp rax, rbx")
            writecode("    cmovg rcx, rdx")
            writecode("    push rcx")
        case Greater_Equal:
            writecode("    xor rcx, rcx")
            writecode("    mov rdx, 1")
            writecode("    pop rbx")
            writecode("    pop rax")
            writecode("    cmp rax, rbx")
            writecode("    cmovge rcx, rdx")
            writecode("    push rcx")
        case Less:
            writecode("    xor rcx, rcx")
            writecode("    mov rdx, 1")
            writecode("    pop rbx")
            writecode("    pop rax")
            writecode("    cmp rax, rbx")
            writecode("    cmovl rcx, rdx")
            writecode("    push rcx")
        case Less_Equal:
            writecode("    xor rcx, rcx")
            writecode("    mov rdx, 1")
            writecode("    pop rbx")
            writecode("    pop rax")
            writecode("    cmp rax, rbx")
            writecode("    cmovle rcx, rdx")
            writecode("    push rcx")
        case Not_Equal:
            writecode("    xor rcx, rcx")
            writecode("    mov rdx, 1")
            writecode("    pop rbx")
            writecode("    pop rax")
            writecode("    cmp rax, rbx")
            writecode("    cmovne rcx, rdx")
            writecode("    push rcx")

        case If:
            writecode("    pop rax")
            writecode("    test rax, rax")
            writecode("    jz .end{}", code_ip)
        case Else:
            writecode("    jmp .end{}", code_ip)
            writecode(".end{}:", v.address)
        case Fi:
            writecode(".end{}:", v.address)

        case Do:
            jump_address_on_false := v.use_self ? code_ip : v.address
            writecode(".start{}:", code_ip)
            writecode("    pop rax")
            writecode("    test rax, rax")
            writecode("    jz .end{}", jump_address_on_false)
        case For_Range:
            writecode("    mov rax, [ret_stack_ptr]")
            writecode("    sub rax, 8")
            writecode("    mov [ret_stack_ptr], rax")
            writecode("    pop rbx")
            writecode("    mov [rax+0], rbx")
            writecode(".start{}:", code_ip)
            writecode("    mov rax, [ret_stack_ptr]")
            writecode("    add rax, 0")
            writecode("    push QWORD [rax]")
            bindsCount += 1

        case Loop:
            if v.bindings > 0 {
                for x := v.bindings - 1; x >= 0; x -= 1 {
                    writecode("    mov rax, [ret_stack_ptr]")
                    writecode("    pop rbx")
                    writecode("    mov [rax+{}], rbx", x * 8)
                }
            }

            writecode("    jmp .start{}", v.address)
            writecode(".end{}:", v.address)

            if v.bindings > 0 {
                writecode("    mov rax, [ret_stack_ptr]")
                writecode("    add rax, {}", v.bindings * 8)
                writecode("    mov [ret_stack_ptr], rax")
                bindsCount -= v.bindings
            }

        case Assembly:
        case Call_Function:
            writecode("   mov rax, rsp")
            writecode("   mov rsp, [ret_stack_ptr]")
            writecode("   call fn{} ; {}", v.address, v.name)
            writecode("   mov [ret_stack_ptr], rsp")
            writecode("   mov rsp, rax")
        case Call_C_Function:
            // TODO: Add registries for floating point args and returns
            input_regs := []string{"rdi", "rsi", "rdx", "rcx", "r8", "r9"}
            output_regs := []string{"rax", "rdx"}

            sliced_inputs := input_regs[:v.inputs]

            for x := v.inputs - 1; x >= 0; x -= 1 {
                writecode("    pop {}", sliced_inputs[x])
            }

            for x := 0; x < v.outputs; x += 1 {
                writecode("    push {}", output_regs[x])
            }

            writecode("    call {}", v.name)
        case Let_Bind:
            newBinds := v.val
            writecode("    mov rax, [ret_stack_ptr]")
            writecode("    sub rax, {}", newBinds * 8)
            writecode("    mov [ret_stack_ptr], rax")
            for x := newBinds - 1; x >= 0; x -= 1 {
                writecode("    pop rbx")
                writecode("    mov [rax+{}], rbx", x * 8)
            }
            bindsCount += newBinds
        case Let_Unbind:
            unbinds := v.val
            writecode("    mov rax, [ret_stack_ptr]")
            writecode("    add rax, {}", unbinds * 8)
            writecode("    mov [ret_stack_ptr], rax")
            bindsCount -= unbinds
        case Let_Rebind:
        case Print:
            if v.type == .Bool || v.type == .Uint || v.type == .Int || v.type == .Byte {
                writecode("    pop rdi")
                writecode("    call print_number")
            } else {
                writecode("    pop rdi")
                writecode("    call printf")
            }
        case Return:
            // TODO: free up local static memory and bindings
            if bindsCount > 0 {
                writecode("    mov rax, [ret_stack_ptr]")
                writecode("    add rax, {}", bindsCount * 8)
                writecode("    mov [ret_stack_ptr], rax")
            }
            writecode("    mov rax, rsp")
            writecode("    mov rsp, [ret_stack_ptr]")
            // writecode("    add rsp, {}", local_memory)
            writecode("    ret")
        }
    }

    writecode(";; end fn {} ({}:{}:{})", name, pos.filename, pos.line, pos.column)
}

gen_ascii :: proc(s: string) -> string {
    result := strings.builder_make(context.temp_allocator)
    is_escaped := false

    for x := 0; x < len(s); x += 1 {
        c := s[x]
        if c == '\\' { is_escaped = true; continue }
        if is_escaped {
            switch c {
            case 'n': strings.write_int(&result, 10)
            }
            is_escaped = false
            strings.write_byte(&result, ',')
            continue
        }

        strings.write_int(&result, int(c))

        strings.write_byte(&result, ',')
    }

    // for r in s {
    //     strings.write_int(&result, int(r))
    //     strings.write_string(&result, ",")
    // }

    // strings.write_byte(&result, '"')
    // strings.write_string(&result, s)
    // strings.write_byte(&result, '"')

    strings.write_string(&result, "0")

    return strings.to_string(result)
}

escaped :: proc(s: string) -> string {
    // used for comments, not important
    result := strings.builder_make(context.temp_allocator)
    for r in s {
        strings.write_escaped_rune(&result, r, '\\')
    }
    return strings.to_string(result)
}

gen_compilation_unit :: proc() {
    // Temporary, since it's only used in this scope
    result := strings.builder_make(context.temp_allocator)
    defer strings.builder_destroy(&result)

    writeln(&result, string(gen.prepend.buf[:]))
    strings.builder_destroy(&gen.prepend)

    writeln(&result, string(gen.code.buf[:]))
    strings.builder_destroy(&gen.code)

    writeln(&result, string(gen.data.buf[:]))
    strings.builder_destroy(&gen.data)

    os.write_entire_file(fmt.tprintf("{}.asm", output_filename), result.buf[:])
}
