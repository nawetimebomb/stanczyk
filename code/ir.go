package main

type OpCode int

const (
	// Constants
	OP_PUSH_BOOL OpCode = iota
	OP_PUSH_INT
	OP_PUSH_STR

	// Intrinscis
	OP_ADD
	OP_DIVIDE
	OP_DROP
	OP_MULTIPLY
	OP_PRINT
	OP_SUBSTRACT
	OP_SWAP
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
