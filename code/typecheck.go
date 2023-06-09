package main

import (
	"fmt"
)

type DataType int

const (
	DATA_EMPTY DataType = iota
	DATA_BOOL
	DATA_INT
	DATA_PTR
	DATA_ANY
)

type Typecheck struct {
	chunk      Chunk
	stack      [32]DataType
	stackCount int
	scope      int
}

var tc Typecheck

func getStackValues() string {
	r := ""

	for index := 0; index < tc.stackCount; index++ {
		r += getDataTypeName(tc.stack[index])

		if (index != tc.stackCount - 1) {
			r += " "
		}
	}

	return r
}

func getOperationName(op OpCode) string {
	name := "Unhandled"
	switch op {
	case OP_ADD: name = "+ (add)"
	case OP_DIVIDE: name = "div"
	case OP_DROP: name = "drop"
	case OP_MULTIPLY: name = "* (multiply)"
	case OP_PRINT: name = "print"
	case OP_SUBSTRACT: name = "- (substract)"
	case OP_SWAP: name = "swap"
	}

	return name
}

func getDataTypeName(v DataType) string {
	r := ""
	switch v {
	case DATA_EMPTY: r = ""
	case DATA_BOOL:  r = "bool"
	case DATA_INT:	 r = "int"
	case DATA_PTR:   r = "ptr"
	case DATA_ANY:   r = "any"
	}
	return r
}

func getDataTypeNames(dt []DataType) string {
	r := ""

	for i, v := range dt {
		r += getDataTypeName(v)
		if i != len(dt) -1 && v != DATA_EMPTY {
			r += " "
		}
	}

	return r
}

func assertArgumentType(test []DataType, want []DataType, op OpCode, loc Location) {
	errFound := false

	for i, t := range test {
		if want[i] == DATA_ANY {
			if t == DATA_EMPTY {
				errFound = true
				break
			}
		} else {
			if want[i] != t {
				errFound = true
				break
			}
		}
	}

	if errFound {
		msg := fmt.Sprintf(MsgTypecheckArgumentsTypeMismatch,
			getOperationName(op), getDataTypeNames(test), getDataTypeNames(want))
		ReportErrorAtLocation(msg, loc)
		ExitWithError(CodeTypecheckError)
	}
}

func (this *Typecheck) push(t DataType) {
	this.stack[this.stackCount] = t
	this.stackCount++
}

func (this *Typecheck) pop() DataType {
	if this.stackCount == 0 {
		return DATA_EMPTY
	}
	this.stackCount--
	v := this.stack[this.stackCount]
	this.stack[this.stackCount] = DATA_EMPTY
	return v
}

func dtArray(values ...DataType) []DataType {
	var r []DataType
	for _, t := range values {
		r = append(r, t)
	}
	return r
}

func typecheckApplication() {
	for _, code := range tc.chunk.code {
		instruction := code.op
		loc := code.loc

		switch instruction {
		// Constants
		case OP_PUSH_BOOL:
			tc.push(DATA_BOOL)
		case OP_PUSH_INT:
			tc.push(DATA_INT)
		case OP_PUSH_STR:
			tc.push(DATA_INT)
			tc.push(DATA_PTR)

		// Intrinsics
		case OP_ADD, OP_SUBSTRACT, OP_MULTIPLY:
			b := tc.pop()
			a := tc.pop()
			assertArgumentType(dtArray(a, b), dtArray(DATA_INT, DATA_INT), instruction, loc)
			tc.push(DATA_INT)
		case OP_DIVIDE:
			b := tc.pop()
			a := tc.pop()
			assertArgumentType(dtArray(a, b), dtArray(DATA_INT, DATA_INT), instruction, loc)
			tc.push(DATA_INT)
			tc.push(DATA_INT)
		case OP_DROP:
			a := tc.pop()
			assertArgumentType(dtArray(a), dtArray(DATA_ANY), instruction, loc)
		case OP_DUP:
			a := tc.pop()
			assertArgumentType(dtArray(a), dtArray(DATA_ANY), instruction, loc)
			tc.push(a)
			tc.push(a)
		case OP_EQUAL, OP_NOT_EQUAL, OP_GREATER, OP_GREATER_EQUAL, OP_LESS, OP_LESS_EQUAL:
			b := tc.pop()
			a := tc.pop()
			assertArgumentType(dtArray(a, b), dtArray(DATA_INT, DATA_INT), instruction, loc)
			tc.push(DATA_BOOL)
		case OP_JUMP_IF_FALSE:
			a := tc.pop()
			assertArgumentType(dtArray(a), dtArray(DATA_BOOL), instruction, loc)
		case OP_PRINT:
			a := tc.pop()
			assertArgumentType(dtArray(a), dtArray(DATA_ANY), instruction, loc)
		case OP_SYSCALL3:
			d := tc.pop()
			c := tc.pop()
			b := tc.pop()
			a := tc.pop()
			assertArgumentType(dtArray(a, b, c, d),
				dtArray(DATA_INT, DATA_PTR, DATA_INT, DATA_INT), instruction, loc)
			tc.push(DATA_INT)
		case OP_SWAP:
			b := tc.pop()
			a := tc.pop()
			assertArgumentType(dtArray(a, b), dtArray(DATA_ANY, DATA_ANY), instruction, loc)
			tc.push(b)
			tc.push(a)

		case OP_EOC:
			if tc.stackCount > 0 {
				msg := fmt.Sprintf(MsgTypecheckUnhandledStack, getStackValues())
				ReportErrorAtEOF(msg)
				ExitWithError(CodeTypecheckError)
			}
		}
	}
}

func TypecheckRun(chunk Chunk) {
	tc.chunk = chunk

	typecheckApplication()
}
