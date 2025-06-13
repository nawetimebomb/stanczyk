package main

import "core:fmt"
import "core:os"
import "core:strings"

Generator :: struct {
    prepend: strings.Builder,

    code: strings.Builder,
    data: strings.Builder,

    global_ip:        uint,
    global_mem_count: uint,
    global_code:      Code,

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

    for &f in functions {
        if f.called {
            gen_function(&f)
        }
    }

    gen_compilation_unit()
}

gen_bootstrap :: proc() {
    // PREPEND BEGINS HERE
    writemeta("global _start")
    writemeta("extern exit")

    for fname in C_functions {
        if fname == "exit" { continue }
        writemeta("extern {}", fname)
    }
    // PREPEND ENDS HERE

    // CODE BEGINS HERE
    writecode("section .text")
    writecode("_start:")
    writecode(";; global code starts here")

    for c in gen.global_code { gen_op(c) }

    writecode(";; global code ends here")

    writecode("    mov [args_ptr], rsp")
    writecode("    mov rax, ret_stack_ptr_end")

    writecode(".stanczyk_user_program:")
    writecode("    mov [ret_stack_ptr], rax")
    writecode("    mov rax, rsp")
    writecode("    mov rsp, [ret_stack_ptr]")
    writecode("    call fn{}", gen.main_func_address)
    writecode("    mov [ret_stack_ptr], rsp")
    writecode("    mov rsp, rax")
    writecode("    xor rdi, rdi")
    writecode("    call exit")
    writecode(";; user program definitions starts here")
    // CODE ENDS HERE

    // DATA BEGINS HERE
    writedata("section .bss")
    writedata("args_ptr: resq 1")
    writedata("ret_stack_ptr: resq 1")
    writedata("ret_stack: resb 65535")
    writedata("ret_stack_ptr_end:")
    writedata("stanczyk_static: resb {}", gen.global_mem_count)

    writedata("section .data")
    writedata("EMPTY_STRING: db 0")
    writedata("FMT_INT: db 37,100,10,0")
    for key, value in strings_table {
        writedata("str_{}: db {}", value, gen_ascii(key))
    }
    // DATA ENDS HERE
}

gen_function :: proc(f: ^Function) {
    name := f.entity.name
    pos := f.entity.pos
    function_ip := f.entity.address
    f.binds_count = 0
    writecode("fn{}:", function_ip)
    writecode(";; start fn {} ({}:{}:{})", name, pos.filename, pos.line, pos.column)
    writecode("    sub rsp, {}", f.local_mem)
    writecode("    mov [ret_stack_ptr], rsp")
    writecode("    mov rsp, rax")

    for c in f.code { gen_op(c, f) }

    writecode(";; end fn {} ({}:{}:{})", name, pos.filename, pos.line, pos.column)
}

gen_op :: proc(c: Bytecode, f: ^Function = nil) {
    code_ip := c.address
    writecode(
        ".ip{}: ;; {} ({}:{}:{})", code_ip,
        bytecode_to_string(c), c.filename, c.line, c.column,
    )

    switch v in c.variant {
    case Push_Bool:
        writecode("    mov rax, {}", v.val ? "1" : "0")
        writecode("    push rax")
    case Push_Bound:
        if v.use_pointer {
            writecode("    mov rax, [ret_stack_ptr]")
            writecode("    add rax, {}", v.val * 8)
            writecode("    push rax")
        } else {
            writecode("    mov rax, [ret_stack_ptr]")
            writecode("    add rax, {}", v.val * 8)
            writecode("    push QWORD [rax]")
        }

    case Push_Byte:
        writecode("    xor rax, rax")
        writecode("    mov al, {}", int(v.val))
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
        if v.use_pointer {
            writecode("    mov rax, stanczyk_static")
            writecode("    add rax, {}", v.val)
            writecode("    push rax")
        } else {
            writecode("    mov rax, stanczyk_static")
            writecode("    add rax, {}", v.val)
            writecode("    push QWORD [rax]")
        }
    case Push_Var_Local:
        offset := v.val + uint(f.binds_count * 8)

        if v.use_pointer {
            writecode("    mov rax, [ret_stack_ptr]")
            writecode("    add rax, {}", offset)
            writecode("    push rax")
        } else {
            writecode("    mov rax, [ret_stack_ptr]")
            writecode("    add rax, {}", offset)
            writecode("    push QWORD [rax]")
        }
    case Declare_Var_Global:
        writecode("    mov rax, stanczyk_static")
        writecode("    xor rbx, rbx")
        if !v.set {
            switch v.kind {
            case .Invalid: assert(false)
            case .Bool:   writecode("    mov rbx, 0")
            case .Byte:   writecode("    mov bl, 0")
            case .Int:    writecode("    mov rbx, 0")
            case .String: writecode("    mov rbx, EMPTY_STRING")
            }
            writecode("    push rbx")
        }
        writecode("    pop rbx")
        writecode("    mov [rax+{}], rbx", v.offset)
    case Declare_Var_Local:
        writecode("    mov rax, [ret_stack_ptr]")
        writecode("    add rax, {}", v.offset)
        writecode("    xor rbx, rbx")
        if !v.set {
            switch v.kind {
            case .Invalid: assert(false)
            case .Bool:   writecode("    mov rbx, 0")
            case .Byte:   writecode("    mov bl, 0")
            case .Int:    writecode("    mov rbx, 0")
            case .String: writecode("    mov rbx, EMPTY_STRING")
            }
            writecode("    push rbx")
        }
        writecode("    pop rbx")
        writecode("    mov [rax], rbx")
    case Get_Byte:
        writecode("    pop rbx")
        writecode("    pop rax")
        writecode("    add rax, rbx")
        writecode("    xor rbx, rbx")
        writecode("    mov bl, [rax]")
        writecode("    push rbx")
    case Set:
        writecode("    pop rax")
        writecode("    pop rbx")
        writecode("    mov [rax], rbx")
    case Set_Byte:
        writecode("    pop rbx")
        writecode("    pop rax")
        writecode("    add rax, rbx")
        writecode("    pop rcx")
        writecode("    mov [rax], cl")
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
    case Comparison:
        writecode("    xor rcx, rcx")
        writecode("    mov rdx, 1")
        writecode("    pop rbx")
        writecode("    pop rax")
        writecode("    cmp rax, rbx")
        switch v.kind {
        case .eq: writecode("    cmove rcx, rdx")
        case .ge: writecode("    cmovge rcx, rdx")
        case .gt: writecode("    cmovg rcx, rdx")
        case .le: writecode("    cmovle rcx, rdx")
        case .lt: writecode("    cmovl rcx, rdx")
        case .ne: writecode("    cmovne rcx, rdx")
        }
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

    case For_Infinite_Start:
        writecode(".start{}:", code_ip)
        writecode("    pop rax")
        writecode("    test rax, rax")
        writecode("    jz .end{}", code_ip)
    case For_Infinite_End:
        writecode("    jmp .start{}", v.address)
        writecode(".end{}:", v.address)
    case For_Range_Start:
        writecode("    mov rax, [ret_stack_ptr]")
        writecode("    sub rax, 16")
        writecode("    mov [ret_stack_ptr], rax")
        writecode("    pop rbx")
        writecode("    mov [rax+8], rbx") // limit
        writecode("    pop rbx")
        writecode("    mov [rax+0], rbx") // index
        writecode(".start{}:", code_ip)
        writecode("    mov r8, [ret_stack_ptr]")
        writecode("    xor rcx, rcx")
        writecode("    mov rdx, 1")
        writecode("    mov rbx, [rax+0]")
        writecode("    mov rax, [rax+8]")
        writecode("    cmp rax, rbx")
        switch v.kind {
        case .eq: writecode("    cmove rcx, rdx")
        case .ge: writecode("    cmovge rcx, rdx")
        case .gt: writecode("    cmovg rcx, rdx")
        case .le: writecode("    cmovle rcx, rdx")
        case .lt: writecode("    cmovl rcx, rdx")
        case .ne: writecode("    cmovne rcx, rdx")
        }
        writecode("    test rcx, rcx")
        writecode("    jz .end{}", code_ip)
        f.binds_count += 2
    case For_Range_End:
        if v.autoincrement != .off {
            writecode("    mov rax, [ret_stack_ptr]")
            writecode("    mov rbx, [rax+0]")
            writecode("    {} rbx, 1", v.autoincrement == .up ? "add" : "sub")
            writecode("    mov [rax+0], rbx")
        }

        writecode("    jmp .start{}", v.address)
        writecode(".end{}:", v.address)
        writecode("    mov rax, [ret_stack_ptr]")
        writecode("    add rax, 16")
        writecode("    mov [ret_stack_ptr], rax")
        f.binds_count -= 2
    case For_String_Start:
        writecode("    mov rax, [ret_stack_ptr]")
        writecode("    sub rax, 24")
        writecode("    mov [ret_stack_ptr], rax")
        writecode("    pop rbx")
        writecode("    xor rcx, rcx")
        writecode("    mov cl, [rbx]")
        writecode("    mov [rax+16], rbx") // the original string
        writecode("    mov QWORD [rax+8], 0") // index
        writecode("    mov [rax+0], rcx") // character
        writecode(".start{}:", code_ip)
        writecode("    mov rbx, [ret_stack_ptr]")
        writecode("    xor rax, rax")
        writecode("    mov rax, [rbx+0]")
        writecode("    test rax, rax")
        writecode("    jz .end{}", code_ip)
        f.binds_count += 3
    case For_String_End:
        writecode("    mov rax, [ret_stack_ptr]")
        // updating the index
        writecode("    mov rbx, [rax+8]")
        writecode("    add rbx, 1")
        writecode("    mov [rax+8], rbx")
        // updating the character
        writecode("    xor rdx, rdx")
        writecode("    mov rcx, [rax+16]")
        writecode("    add rcx, rbx")
        writecode("    mov dl, [rcx]")
        writecode("    mov [rax+0], rdx")
        writecode("    jmp .start{}", v.address)
        writecode(".end{}:", v.address)
        writecode("    mov rax, [ret_stack_ptr]")
        writecode("    add rax, 24")
        writecode("    mov [ret_stack_ptr], rax")
        f.binds_count -= 3

    case Drop:
        writecode("    pop rax")
    case Dup:
        writecode("    pop rax")
        writecode("    push rax")
        writecode("    push rax")
    case Nip:
        writecode("    pop rbx")
        writecode("    pop rax")
        writecode("    push rbx")
    case Over:
        writecode("    pop rbx")
        writecode("    pop rax")
        writecode("    push rax")
        writecode("    push rbx")
        writecode("    push rax")
    case Rotate:
        writecode("    pop rcx")
        writecode("    pop rbx")
        writecode("    pop rax")
        writecode("    push rbx")
        writecode("    push rcx")
        writecode("    push rax")
    case Rotate_Neg:
        writecode("    pop rcx")
        writecode("    pop rbx")
        writecode("    pop rax")
        writecode("    push rcx")
        writecode("    push rax")
        writecode("    push rbx")
    case Swap:
        writecode("    pop rbx")
        writecode("    pop rax")
        writecode("    push rbx")
        writecode("    push rax")
    case Tuck:
        writecode("    pop rbx")
        writecode("    pop rax")
        writecode("    push rbx")
        writecode("    push rax")
        writecode("    push rbx")

    case Assembly:
        // TODO: this should be part of the string struct
        writecode("    pop rsi")
        writecode("    xor rdx, rdx")
        writecode(".next_char:")
        writecode("    cmp byte [rsi+rdx], 0")
        writecode("    je .done")
        writecode("    inc rdx")
        writecode("    jmp .next_char")
        writecode(".done:")
        writecode("    mov rax, 1")
        writecode("    mov rdi, 1")
        writecode("    syscall")
    case Call_Function:
        writecode("    mov rax, rsp")
        writecode("    mov rsp, [ret_stack_ptr]")
        writecode("    call fn{} ; {}", v.address, v.name)
        writecode("    mov [ret_stack_ptr], rsp")
        writecode("    mov rsp, rax")
    case Call_C_Function:
        // TODO: Add registries for floating point args and returns
        input_regs := []string{"rdi", "rsi", "rdx", "rcx", "r8", "r9"}
        output_regs := []string{"rax", "rdx"}

        sliced_inputs := input_regs[:v.inputs]

        for x := v.inputs - 1; x >= 0; x -= 1 {
            writecode("    pop {}", sliced_inputs[x])
        }

        writecode("    mov rax, 0")
        writecode("    call {}", v.name)

        for x := 0; x < v.outputs; x += 1 {
            writecode("    push {}", output_regs[x])
        }
    case Let_Bind:
        new_binds := v.val
        writecode("    mov rax, [ret_stack_ptr]")
        writecode("    sub rax, {}", new_binds * 8)
        writecode("    mov [ret_stack_ptr], rax")
        for x := new_binds - 1; x >= 0; x -= 1 {
            writecode("    pop rbx")
            writecode("    mov [rax+{}], rbx", x * 8)
        }
        f.binds_count += new_binds
    case Let_Unbind:
        unbinds := v.val
        writecode("    mov rax, [ret_stack_ptr]")
        writecode("    add rax, {}", unbinds * 8)
        writecode("    mov [ret_stack_ptr], rax")
        f.binds_count -= unbinds
    case Return:
        if f.binds_count > 0 {
            writecode("    mov rax, [ret_stack_ptr]")
            writecode("    add rax, {}", f.binds_count * 8)
            writecode("    mov [ret_stack_ptr], rax")
        }
        writecode("    mov rax, rsp")
        writecode("    mov rsp, [ret_stack_ptr]")
        writecode("    add rsp, {}", f.local_mem)
        writecode("    ret")
    }
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
            case 't': strings.write_int(&result, 9)
            }
            is_escaped = false
            strings.write_byte(&result, ',')
            continue
        }

        strings.write_int(&result, int(c))

        strings.write_byte(&result, ',')
    }

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
