package main

import (
	"fmt"
	"runtime"
)

type Codegen struct {
	asm *Assembly
}

var codegen Codegen

func getAsciiValues(s string) (string, int) {
	count := 0
	nextEscaped := false
	ascii := ""

	for _, c := range s {
		if c == '\\' {
			nextEscaped = true
			continue
		}

		if nextEscaped {
			switch c {
			case 't':
				ascii += "9,"
				count++
			case 'n':
				ascii += "10,"
				count++
			case 'e':
				ascii += "27,"
				count++
			}

			nextEscaped = false
			continue
		}

		val := fmt.Sprintf("%v,", c)
		ascii += val
		count++
	}

	ascii += "0"
	count++

	return ascii, count
}

func generateLinuxX86() {
	mainFuncIP := -1
	asm := codegen.asm

	asm.WriteText("section .text")
    asm.WriteText("global _start")
    asm.WriteText("print:")
    asm.WriteText("    mov     r9, -3689348814741910323")
    asm.WriteText("    sub     rsp, 40")
    asm.WriteText("    mov     BYTE [rsp+31], 10")
    asm.WriteText("    lea     rcx, [rsp+30]")
    asm.WriteText(".L2:")
    asm.WriteText("    mov     rax, rdi")
    asm.WriteText("    lea     r8, [rsp+32]")
    asm.WriteText("    mul     r9")
    asm.WriteText("    mov     rax, rdi")
    asm.WriteText("    sub     r8, rcx")
    asm.WriteText("    shr     rdx, 3")
    asm.WriteText("    lea     rsi, [rdx+rdx*4]")
    asm.WriteText("    add     rsi, rsi")
    asm.WriteText("    sub     rax, rsi")
    asm.WriteText("    add     eax, 48")
    asm.WriteText("    mov     BYTE [rcx], al")
    asm.WriteText("    mov     rax, rdi")
    asm.WriteText("    mov     rdi, rdx")
    asm.WriteText("    mov     rdx, rcx")
    asm.WriteText("    sub     rcx, 1")
    asm.WriteText("    cmp     rax, 9")
    asm.WriteText("    ja      .L2")
    asm.WriteText("    lea     rax, [rsp+32]")
    asm.WriteText("    mov     edi, 1")
    asm.WriteText("    sub     rdx, rax")
    asm.WriteText("    xor     eax, eax")
    asm.WriteText("    lea     rsi, [rsp+32+rdx]")
    asm.WriteText("    mov     rdx, r8")
    asm.WriteText("    mov     rax, 1")
    asm.WriteText("    syscall")
    asm.WriteText("    add     rsp, 40")
    asm.WriteText("    ret")
    asm.WriteText(";; user program definitions starts here")

	asm.WriteData("section .data")

	asm.WriteBss("section .bss")
	asm.WriteBss("args_ptr: resq 1")
	asm.WriteBss("return_stack_rsp: resq 1")
	asm.WriteBss("return_stack: resb 65536")
	asm.WriteBss("return_stack_rsp_end:")

	for _, function := range TheProgram.chunks {
		if !function.called {
			continue
		}
		if function.name == "main" {
			mainFuncIP = function.ip
		}

		asm.WriteText("fn%d:", function.ip)
		asm.WriteText(";; start function %s (%s:%d:%d)", function.name,
			function.loc.f, function.loc.l, function.loc.c)
		asm.WriteText("    sub rsp, 0")
		asm.WriteText("    mov [return_stack_rsp], rsp")
		asm.WriteText("    mov rsp, rax")

		for index, code := range function.code {
			instruction := code.op
			loc := code.loc
			value := code.value

			asm.WriteText(".ip%d:", index)

			switch instruction {
			// Constants
			case OP_PUSH_BOOL:
				boolText := map[int]string{1:"true", 0:"false"} [value.(int)]
				asm.WriteText(";; %s (%s:%d:%d)", boolText, loc.f, loc.l, loc.c)
				asm.WriteText("    mov rax, %d", value)
				asm.WriteText("    push rax")
			case OP_PUSH_INT:
				asm.WriteText(";; %d (%s:%d:%d)", value, loc.f, loc.l, loc.c)
				asm.WriteText("    mov rax, %d", value)
				asm.WriteText("    push rax")
			case OP_PUSH_STR:
				ascii, _ := getAsciiValues(value.(string))
				asm.WriteText(";; \"%s\" (%s:%d:%d)", value, loc.f, loc.l, loc.c)
				asm.WriteText("    push str_%d", len(asm.data))
				asm.WriteData("str_%d: db %s", len(asm.data), ascii)

				// Intrinsics
			case OP_ADD:
				asm.WriteText(";; + (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    pop rax")
				asm.WriteText("    pop rbx")
				asm.WriteText("    add rax, rbx")
				asm.WriteText("    push rax")
			case OP_ARGC:
				asm.WriteText(";; argc (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    mov rax, [args_ptr]")
                asm.WriteText("    mov rax, [rax]")
                asm.WriteText("    push rax")
			case OP_ARGV:
				asm.WriteText(";; argv (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    mov rax, [args_ptr]")
				asm.WriteText("    add rax, 8")
                asm.WriteText("    push rax")
			case OP_CAST:
				asm.WriteText(";; cast to %s (%s:%d:%d)",
					getDataTypeName(value.(DataType)), loc.f, loc.l, loc.c)
			case OP_DIVIDE:
				asm.WriteText(";; / (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    xor rdx, rdx")
				asm.WriteText("    pop rbx")
				asm.WriteText("    pop rax")
				asm.WriteText("    div rbx")
				asm.WriteText("    push rax")
				asm.WriteText("    push rdx")
			case OP_DROP:
				asm.WriteText(";; drop (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    pop rax")
			case OP_DUP:
				asm.WriteText(";; dup (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    pop rax")
				asm.WriteText("    push rax")
				asm.WriteText("    push rax")
			case OP_EQUAL:
				asm.WriteText(";; = (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    xor rcx, rcx")
				asm.WriteText("    mov rdx, 1")
				asm.WriteText("    pop rax")
				asm.WriteText("    pop rbx")
				asm.WriteText("    cmp rax, rbx")
				asm.WriteText("    cmove rcx, rdx")
				asm.WriteText("    push rcx")
			case OP_GREATER:
				asm.WriteText(";; > (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    xor rcx, rcx")
				asm.WriteText("    mov rdx, 1")
				asm.WriteText("    pop rbx")
				asm.WriteText("    pop rax")
				asm.WriteText("    cmp rax, rbx")
				asm.WriteText("    cmovg rcx, rdx")
				asm.WriteText("    push rcx")
			case OP_GREATER_EQUAL:
				asm.WriteText(";; >= (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    xor rcx, rcx")
				asm.WriteText("    mov rdx, 1")
				asm.WriteText("    pop rbx")
				asm.WriteText("    pop rax")
				asm.WriteText("    cmp rax, rbx")
				asm.WriteText("    cmovge rcx, rdx")
				asm.WriteText("    push rcx")
			case OP_LESS:
				asm.WriteText(";; < (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    xor rcx, rcx")
				asm.WriteText("    mov rdx, 1")
				asm.WriteText("    pop rbx")
				asm.WriteText("    pop rax")
				asm.WriteText("    cmp rax, rbx")
				asm.WriteText("    cmovl rcx, rdx")
				asm.WriteText("    push rcx")
			case OP_LESS_EQUAL:
				asm.WriteText(";; <= (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    xor rcx, rcx")
				asm.WriteText("    mov rdx, 1")
				asm.WriteText("    pop rbx")
				asm.WriteText("    pop rax")
				asm.WriteText("    cmp rax, rbx")
				asm.WriteText("    cmovle rcx, rdx")
				asm.WriteText("    push rcx")
			case OP_LOAD8:
				asm.WriteText("    pop rax")
                asm.WriteText("    xor rbx, rbx")
                asm.WriteText("    mov bl, [rax]")
                asm.WriteText("    push rbx")
			case OP_LOAD16:
				asm.WriteText("    pop rax")
                asm.WriteText("    xor rbx, rbx")
                asm.WriteText("    mov bx, [rax]")
                asm.WriteText("    push rbx")
			case OP_LOAD32:
				asm.WriteText("    pop rax")
                asm.WriteText("    xor rbx, rbx")
                asm.WriteText("    mov ebx, [rax]")
                asm.WriteText("    push rbx")
			case OP_LOAD64:
				asm.WriteText("    pop rax")
                asm.WriteText("    xor rbx, rbx")
                asm.WriteText("    mov rbx, [rax]")
                asm.WriteText("    push rbx")
			case OP_MULTIPLY:
				asm.WriteText(";; * (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    pop rax")
				asm.WriteText("    pop rbx")
				asm.WriteText("    mul rbx")
				asm.WriteText("    push rax")
			case OP_NOT_EQUAL:
				asm.WriteText(";; != (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    xor rcx, rcx")
				asm.WriteText("    mov rdx, 1")
				asm.WriteText("    pop rax")
				asm.WriteText("    pop rbx")
				asm.WriteText("    cmp rax, rbx")
				asm.WriteText("    cmovne rcx, rdx")
				asm.WriteText("    push rcx")
			case OP_OVER:
				asm.WriteText(";; over (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    pop rax")
				asm.WriteText("    pop rbx")
				asm.WriteText("    push rbx")
				asm.WriteText("    push rax")
				asm.WriteText("    push rbx")
			case OP_PRINT:
				asm.WriteText(";; print (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    pop rdi")
				asm.WriteText("    call print")
			case OP_SUBSTRACT:
				asm.WriteText(";; - (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    pop rbx")
				asm.WriteText("    pop rax")
				asm.WriteText("    sub rax, rbx")
				asm.WriteText("    push rax")
			case OP_STORE8:
                asm.WriteText("    pop rax")
                asm.WriteText("    pop rbx")
                asm.WriteText("    mov [rax], bl")
			case OP_STORE16:
                asm.WriteText("    pop rax")
                asm.WriteText("    pop rbx")
                asm.WriteText("    mov [rax], bx")
			case OP_STORE32:
                asm.WriteText("    pop rax")
                asm.WriteText("    pop rbx")
                asm.WriteText("    mov [rax], ebx")
			case OP_STORE64:
                asm.WriteText("    pop rax")
                asm.WriteText("    pop rbx")
                asm.WriteText("    mov [rax], rbx")
			case OP_SWAP:
				asm.WriteText(";; swap (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    pop rax")
				asm.WriteText("    pop rbx")
				asm.WriteText("    push rax")
				asm.WriteText("    push rbx")
			case OP_RET:
				asm.WriteText(";; ret (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    mov rax, rsp")
				asm.WriteText("    mov rsp, [return_stack_rsp]")
				asm.WriteText("    add rsp, %d", value)
				asm.WriteText("    ret")

				// Special
			case OP_SYSCALL:
				regs := []string{"rax", "rdi", "rsi", "rdx", "r10", "r8", "r9",}
				for i, _ := range function.args {
					asm.WriteText("    pop %s", regs[i])
				}
				asm.WriteText("    syscall")
				for range function.rets {
					asm.WriteText("    push rax")
				}
			case OP_WORD:
				fnCall := FindFunction(code)

				asm.WriteText(";; call function %s (%s:%d:%d)", fnCall.name, loc.f, loc.l, loc.c)
				asm.WriteText("    mov rax, rsp")
				asm.WriteText("    mov rsp, [return_stack_rsp]")
				asm.WriteText("    call fn%d", fnCall.ip)
				asm.WriteText("    mov [return_stack_rsp], rsp")
				asm.WriteText("    mov rsp, rax")
			case OP_END_IF:
				asm.WriteText(";; . [if] (%s:%d:%d)", loc.f, loc.l, loc.c)
			case OP_END_LOOP:
				asm.WriteText(";; . [loop] (%s:%d:%d)", loc.f, loc.l, loc.c)
			case OP_IF:
				asm.WriteText(";; if (%s:%d:%d)", loc.f, loc.l, loc.c)
			case OP_JUMP:
				asm.WriteText(";; else (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    jmp .ip%d", value)
			case OP_JUMP_IF_FALSE:
				asm.WriteText(";; do (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    pop rax")
				asm.WriteText("    test rax, rax")
				asm.WriteText("    jz .ip%d", value)
			case OP_LOOP:
				asm.WriteText(";; loop (%s:%d:%d)", loc.f, loc.l, loc.c)
				asm.WriteText("    jmp .ip%d", value)
			}
		}

		asm.WriteText(";; end function %s (%s:%d:%d)", function.name,
			function.loc.f, function.loc.l, function.loc.c)
	}

	asm.WriteText(";; user program definition ends here")
	asm.WriteText("_start:")
	asm.WriteText("    mov [args_ptr], rsp")
	asm.WriteText("    mov rax, return_stack_rsp_end")
	asm.WriteText("    mov [return_stack_rsp], rax")
	asm.WriteText("    call fn%d", mainFuncIP)
	asm.WriteText("    mov rax, 60")
	asm.WriteText("    mov rdi, 0")
	asm.WriteText("    syscall")
}

func CodegenRun(asm *Assembly) {
	codegen.asm = asm

	switch runtime.GOOS {
	case "linux":
		generateLinuxX86()
	default:
		Stanczyk.Error("OS currently not supported")
	}
}
