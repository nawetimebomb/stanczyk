package main

import (
	"fmt"
)

const STACK_SIZE = 10

type Typecheck struct {
	stack      [STACK_SIZE]DataType
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

func getOperationName(code Code) string {
	name := "Unhandled"
	switch code.op {
	case OP_ADD: name = "+ (add)"
	case OP_DIVIDE: name = "div"
	case OP_DROP: name = "drop"
	case OP_JUMP_IF_FALSE: name = "do"
	case OP_LOAD8, OP_LOAD16, OP_LOAD32, OP_LOAD64:
		name = "load"
	case OP_MULTIPLY: name = "* (multiply)"
	case OP_NOT_EQUAL:
		name = "!= (not equal)"
	case OP_PRINT: name = "print"
	case OP_STORE8, OP_STORE16, OP_STORE32, OP_STORE64:
		name = "store"
	case OP_SUBSTRACT: name = "- (substract)"
	case OP_SWAP: name = "swap"
	case OP_WORD: name = code.value.(string)
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

func assertArgumentType(test []DataType, want []DataType, code Code, loc Location) {
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
			getOperationName(code), getDataTypeNames(test), getDataTypeNames(want))
		ReportErrorAtLocation(msg, loc)
		ExitWithError(CodeTypecheckError)
	}
}

func (this *Typecheck) reset() {
	this.stack = [STACK_SIZE]DataType{}
	this.stackCount = 0
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

func TypecheckRun() {
	mainHandled := false
	for _, function := range TheProgram.chunks {
		if !function.called && !function.internal {
			msg := fmt.Sprintf(MsgTypecheckWarningNotCalled, function.name)
			ReportErrorAtLocation(msg, function.loc)
		}

		if function.name == "main" {
			mainHandled = true
			if len(function.args) > 0 || len(function.rets) > 0 {
				ReportErrorAtLocation(MsgTypecheckMainFunctionNoArgumentsOrReturn, function.loc)
				ExitWithError(CodeTypecheckError)
			}
		}

		expectedReturnCount := len(function.rets)

		for _, dt := range function.args {
			tc.push(dt)
		}

		for _, code := range function.code {
			instruction := code.op
			loc := code.loc

			switch instruction {
			// Constants
			case OP_PUSH_BOOL:
				tc.push(DATA_BOOL)
			case OP_PUSH_INT:
				tc.push(DATA_INT)
			case OP_PUSH_STR:
				tc.push(DATA_PTR)

			// Intrinsics
			case OP_ADD, OP_SUBSTRACT, OP_MULTIPLY:
				b := tc.pop()
				a := tc.pop()
				assertArgumentType(dtArray(a, b), dtArray(DATA_INT, DATA_INT), code, loc)
				tc.push(DATA_INT)
			case OP_ARGC:
				tc.push(DATA_INT)
			case OP_ARGV:
				tc.push(DATA_PTR)
			case OP_CAST:
				a := tc.pop()
				assertArgumentType(dtArray(a), dtArray(DATA_ANY), code, loc)
				tc.push(code.value.(DataType))
			case OP_DIVIDE:
				b := tc.pop()
				a := tc.pop()
				assertArgumentType(dtArray(a, b), dtArray(DATA_INT, DATA_INT), code, loc)
				tc.push(DATA_INT)
				tc.push(DATA_INT)
			case OP_DROP:
				a := tc.pop()
				assertArgumentType(dtArray(a), dtArray(DATA_ANY), code, loc)
			case OP_DUP:
				a := tc.pop()
				assertArgumentType(dtArray(a), dtArray(DATA_ANY), code, loc)
				tc.push(a)
				tc.push(a)
			case OP_EQUAL, OP_NOT_EQUAL, OP_GREATER, OP_GREATER_EQUAL, OP_LESS, OP_LESS_EQUAL:
				b := tc.pop()
				a := tc.pop()
				assertArgumentType(dtArray(a, b), dtArray(DATA_ANY, DATA_ANY), code, loc)
				tc.push(DATA_BOOL)
			case OP_JUMP_IF_FALSE:
				a := tc.pop()
				assertArgumentType(dtArray(a), dtArray(DATA_BOOL), code, loc)
			case OP_LOAD8, OP_LOAD16, OP_LOAD32, OP_LOAD64:
				a := tc.pop()
				assertArgumentType(dtArray(a), dtArray(DATA_PTR), code, loc)
				tc.push(DATA_PTR)
			case OP_OVER:
				b := tc.pop()
				a := tc.pop()
				assertArgumentType(dtArray(a, b), dtArray(DATA_ANY, DATA_ANY), code, loc)
				tc.push(a)
				tc.push(b)
				tc.push(a)
			case OP_PRINT:
				a := tc.pop()
				assertArgumentType(dtArray(a), dtArray(DATA_ANY), code, loc)
			case OP_STORE8, OP_STORE16, OP_STORE32, OP_STORE64:
				b := tc.pop()
				a := tc.pop()
				assertArgumentType(dtArray(a, b), dtArray(DATA_PTR, DATA_PTR), code, loc)
			case OP_SWAP:
				b := tc.pop()
				a := tc.pop()
				assertArgumentType(dtArray(a, b), dtArray(DATA_ANY, DATA_ANY), code, loc)
				tc.push(b)
				tc.push(a)

			// Special
			case OP_SYSCALL:
				var have []DataType

				for range function.args {
					t := tc.pop()
					have = append([]DataType{t}, have...)
				}

				assertArgumentType(have, function.args, code, loc)

				for _, dt := range function.rets {
					tc.push(dt)
				}
			case OP_WORD:
				var have []DataType
				fnCall := FindFunction(code)

				for range fnCall.args {
					t := tc.pop()
					have = append([]DataType{t}, have...)
				}

				assertArgumentType(have, fnCall.args, code, loc)

				for _, dt := range fnCall.rets {
					tc.push(dt)
				}
			}
		}

		if tc.stackCount != expectedReturnCount {
			msg := fmt.Sprintf(MsgTypecheckNotExplicitlyReturned,
				function.name, getStackValues())
			ReportErrorAtEOF(msg)
			ExitWithError(CodeTypecheckError)
		}

		tc.reset()
	}

	if !mainHandled {
		ReportErrorAtEOF(MsgTypecheckMissingEntryPoint)
		ExitWithError(CodeTypecheckError)
	}
}
