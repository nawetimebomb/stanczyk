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
	OP_DUP
	OP_END_IF
	OP_END_LOOP
	OP_EQUAL
	OP_GREATER
	OP_GREATER_EQUAL
	OP_IF
	OP_JUMP
	OP_JUMP_IF_FALSE
	OP_LESS
	OP_LESS_EQUAL
	OP_LOOP
	OP_MULTIPLY
	OP_NOT_EQUAL
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
