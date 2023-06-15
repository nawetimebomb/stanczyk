package main

import (
	"fmt"
)

type Codegen struct {
	chunk Chunk
	asm *Assembly
}

var codegen Codegen

func getAsciiValues(s string) (string, int) {
	result := ""
	count := 0

	for index := 0; index < len(s); index++ {
		c := s[index]

		if c == '\\' {
			index++
			c = s[index]
			switch c {
			case 't': c = 9
			case 'n': c = 10
			}
		}

		val := fmt.Sprintf("%v,", c)
		result += val
		count++
	}

	return result, count
}

func generateLinuxX86() {
	asm := codegen.asm

	asm.WriteText("section .text");
    asm.WriteText("global _start");
    asm.WriteText("print:");
    asm.WriteText("    mov     r9, -3689348814741910323");
    asm.WriteText("    sub     rsp, 40");
    asm.WriteText("    mov     BYTE [rsp+31], 10");
    asm.WriteText("    lea     rcx, [rsp+30]");
    asm.WriteText(".L2:");
    asm.WriteText("    mov     rax, rdi");
    asm.WriteText("    lea     r8, [rsp+32]");
    asm.WriteText("    mul     r9");
    asm.WriteText("    mov     rax, rdi");
    asm.WriteText("    sub     r8, rcx");
    asm.WriteText("    shr     rdx, 3");
    asm.WriteText("    lea     rsi, [rdx+rdx*4]");
    asm.WriteText("    add     rsi, rsi");
    asm.WriteText("    sub     rax, rsi");
    asm.WriteText("    add     eax, 48");
    asm.WriteText("    mov     BYTE [rcx], al");
    asm.WriteText("    mov     rax, rdi");
    asm.WriteText("    mov     rdi, rdx");
    asm.WriteText("    mov     rdx, rcx");
    asm.WriteText("    sub     rcx, 1");
    asm.WriteText("    cmp     rax, 9");
    asm.WriteText("    ja      .L2");
    asm.WriteText("    lea     rax, [rsp+32]");
    asm.WriteText("    mov     edi, 1");
    asm.WriteText("    sub     rdx, rax");
    asm.WriteText("    xor     eax, eax");
    asm.WriteText("    lea     rsi, [rsp+32+rdx]");
    asm.WriteText("    mov     rdx, r8");
    asm.WriteText("    mov     rax, 1");
    asm.WriteText("    syscall");
    asm.WriteText("    add     rsp, 40");
    asm.WriteText("    ret");
    asm.WriteText("_start:");
    asm.WriteText(";; user program definitions starts here");

	asm.WriteData("section .data")

	for index, code := range codegen.chunk.code {
		instruction := code.op
		loc := code.loc
		value := code.value

		asm.WriteText("ip_%d:", index)

		switch instruction {
		// Constants
		case OP_PUSH_INT:
			asm.WriteText(";; %d (%s:%d:%d)", value, loc.f, loc.l, loc.c)
			asm.WriteText("    mov rax, %d", value)
			asm.WriteText("    push rax")
		case OP_PUSH_STR:
			str, length := getAsciiValues(value.(string))
			asm.WriteText(";; %s (%s:%d:%d)", value, loc.f, loc.l, loc.c)
			asm.WriteText("    mov rax, %d", length)
			asm.WriteText("    push rax")
			asm.WriteText("    push str_%d", len(asm.data))
			asm.WriteData("str_%d: db %s", len(asm.data), str)

		// Intrinsics
		case OP_ADD:
			asm.WriteText(";; + (%s:%d:%d)", loc.f, loc.l, loc.c)
			asm.WriteText("    pop rax")
			asm.WriteText("    pop rbx")
			asm.WriteText("    add rax, rbx")
			asm.WriteText("    push rax")
		case OP_DROP:
			asm.WriteText(";; drop (%s:%d:%d)", loc.f, loc.l, loc.c)
			asm.WriteText("    pop rax")
		case OP_PRINT:
			asm.WriteText(";; print (%s:%d:%d)", loc.f, loc.l, loc.c)
			asm.WriteText("    pop rdi")
			asm.WriteText("    call print")
		case OP_SYSCALL3:
			asm.WriteText(";; SYSCALL3 (%s:%d:%d)", loc.f, loc.l, loc.c)
			asm.WriteText("    pop rax")
			asm.WriteText("    pop rdi")
			asm.WriteText("    pop rsi")
			asm.WriteText("    pop rdx")
			asm.WriteText("    syscall")
			asm.WriteText("    push rax")

		// Special
		case OP_EOC:
			asm.WriteText(";; user program definition ends here")
			asm.WriteText("    mov rax, 60")
			asm.WriteText("    mov rdi, 0")
			asm.WriteText("    syscall")
		}
	}
}

func CodegenRun(chunk Chunk, asm *Assembly) {
	codegen.chunk = chunk
	codegen.asm = asm

	// TODO: Add different OS check
	generateLinuxX86()
}
