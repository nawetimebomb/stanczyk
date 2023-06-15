package main

type OpCode int

const (
	// Constants
	OP_PUSH_INT OpCode = iota
	OP_PUSH_STR

	// Intrinscis
	OP_ADD
	OP_DROP
	OP_PRINT
	OP_SYSCALL3

	// Special
	OP_EOC
)

type Code struct {
	loc   Location
	op    OpCode
	value any
}

type Chunk struct {
	code []Code
}

func (this *Chunk) Write(code Code) {
	this.code = append(this.code, code)
}
