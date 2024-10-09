package skc

import (
	"fmt"
	"reflect"
)

const STACK_SIZE = 1024

type TypeInfoKind string

const (
	ANY TypeInfoKind = "any"
	BOOLEAN          = "bool"
	BYTE             = "byte"
	INT64            = "int"
	POINTER          = "ptr"
	STRING           = "str"
	UINT64           = "uint"
)

type TypeInfo struct {
	align int
	kind TypeInfoKind
	size int
}

type TypeInfoPointer struct {
	kind TypeInfoKind
}

type Value struct {
	typeInfo TypeInfo
	value any
}

type Typecheck struct {
	stack       [STACK_SIZE]DataType
	stackCount  int
	scope       int
}

type DeadCodeElim struct {
	funcsCalled []int
}

var tc Typecheck
var snapshots [10]Typecheck
var dce DeadCodeElim

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

func getDataTypeName(v DataType) string {
	r := ""
	switch v {
	case DATA_NONE:  r = ""
	case DATA_BOOL:  r = "bool"
	case DATA_CHAR:  r = "char"
	case DATA_INFER: r = "$type"
	case DATA_INT:	 r = "int"
	case DATA_PTR:   r = "ptr"
	case DATA_STR:   r = "str"
	case DATA_ANY:   r = "any"
	}
	return r
}

func getDataTypeNames(dt []DataType) string {
	r := ""

	for i, v := range dt {
		r += getDataTypeName(v)
		if i != len(dt) -1 && v != DATA_NONE {
			r += " "
		}
	}

	return r
}

func assertArgumentTypes(test []DataType, want [][]DataType, code Code, loc Location) {
	var errFound []bool

	for _, w := range want {
		err := false

		for i, t := range test {
			if w[i] == DATA_ANY {
				if t == DATA_NONE {
					err = true
					break
				}
			} else {
				if w[i] != t && t != DATA_ANY {
					err = true
					break
				}
			}
		}

		errFound = append(errFound, err)
	}

	if !Contains(errFound, false) {
		wantsText := ""

		for i, w := range want {
			wantsText += "(" + getDataTypeNames(w) + ")"

			if i != len(want) - 1 {
				wantsText += " or "
			}
		}

		msg := fmt.Sprintf(MsgTypecheckArgumentsTypesMismatch,
			code.op, getDataTypeNames(test), wantsText)
		ReportErrorAtLocation(msg, loc)
		ExitWithError(CodeTypecheckError)
	}
}

func assertArgumentType(test []DataType, want []DataType, code Code, loc Location) {
	errFound := false

	for i, t := range test {
		if want[i] == DATA_ANY || want[i] == DATA_INFER {
			if t == DATA_NONE {
				errFound = true
				break
			}
		} else {
			if want[i] != t && t != DATA_ANY {
				errFound = true
				break
			}
		}
	}

	if errFound {
		fmt.Println(code)
		msg := fmt.Sprintf(MsgTypecheckArgumentsTypeMismatch,
			code.op, getDataTypeNames(test), getDataTypeNames(want))
		ReportErrorAtLocation(msg, loc)
		ExitWithError(CodeTypecheckError)
	}
}

func dtArray(values ...DataType) []DataType {
	var r []DataType
	for _, t := range values {
		r = append(r, t)
	}
	return r
}

func findFunctionByIP(ip int) Function {
	return TheProgram.chunks[ip]
}

func (this *DeadCodeElim) push(i int) {
	this.funcsCalled = append(this.funcsCalled, i)
}

func (this *DeadCodeElim) pop() int {
	var x int
	x = this.funcsCalled[len(this.funcsCalled) - 1]
	this.funcsCalled = this.funcsCalled[:len(this.funcsCalled) - 1]
	return x
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
		return DATA_NONE
	}
	this.stackCount--
	v := this.stack[this.stackCount]
	this.stack[this.stackCount] = DATA_NONE
	return v
}

func ValidateRun() {
	mainHandled := false

	for ifunction, function := range TheProgram.chunks {
		var bindings []DataType
		argumentTypes := function.arguments.types
		returnTypes := function.returns.types

		if function.name == "main" {
			mainHandled = true
			dce.push(function.ip)

			if len(argumentTypes) > 0 || len(returnTypes) > 0 {
				ReportErrorAtLocation(
					MsgTypecheckMainFunctionNoArgumentsOrReturn,
					function.loc,
				)
				ExitWithError(CodeTypecheckError)
			}
		}

		expectedReturnCount := len(returnTypes)

		for _, t := range argumentTypes {
			tc.push(t.typ)
		}

		for icode, code := range function.code {
			instruction := code.op
			loc := code.loc
			value := code.value

			switch instruction {
			// CONSTANT
			case OP_PUSH_BOOL:
				tc.push(DATA_BOOL)
			case OP_PUSH_BIND:
				value := code.value.(int)
				tc.push(bindings[value])
			case OP_PUSH_BIND_ADDR:
				tc.push(DATA_PTR)
			case OP_PUSH_CHAR:
				tc.push(DATA_CHAR)
			case OP_PUSH_INT:
				tc.push(DATA_INT)
			case OP_PUSH_STR:
				tc.push(DATA_STR)
			case OP_PUSH_VAR_GLOBAL:
				for _, v := range TheProgram.variables {
					if v.offset == value.(int) {
						tc.push(v.dtype)
					}
				}
			case OP_PUSH_VAR_GLOBAL_ADDR:
				tc.push(DATA_PTR)
			case OP_PUSH_VAR_LOCAL:
				for _, v := range function.variables {
					if v.offset == value.(int) {
						tc.push(v.dtype)
					}
				}
			case OP_PUSH_VAR_LOCAL_ADDR:
				tc.push(DATA_PTR)

			// MATH ARITHMETICS
			case OP_MULTIPLY:
				b := tc.pop()
				a := tc.pop()
				assertArgumentType(dtArray(a, b), dtArray(DATA_INT, DATA_INT), code, loc)
				tc.push(DATA_INT)

			case OP_STORE:
				b := tc.pop()
				a := tc.pop()
				assertArgumentType(dtArray(a, b), dtArray(DATA_ANY, DATA_PTR), code, loc)
			case OP_STORE_CHAR:
				b := tc.pop()
				a := tc.pop()
				assertArgumentType(
					dtArray(DATA_ANY, DATA_PTR),
					dtArray(a, b), code, loc,
				)
			case OP_LOAD:
				a := tc.pop()
				assertArgumentType(dtArray(a), dtArray(DATA_PTR), code, loc)
				tc.push(DATA_INT)
			case OP_LOAD_CHAR:
				b := tc.pop()
				a := tc.pop()
				assertArgumentType(dtArray(a, b), dtArray(DATA_INT, DATA_PTR), code, loc)
				tc.push(DATA_CHAR)

			case OP_LET_BIND:
				var have []DataType
				var wants []DataType
				newBinds := code.value.(int)
				for i := newBinds; i > 0; i-- {
					a := tc.pop()
					bindings = append([]DataType{a}, bindings...)
					have = append([]DataType{a}, have...)
					wants = append(wants, DATA_ANY)
				}
				assertArgumentType(have, wants, code, loc)
			case OP_LET_UNBIND:
				unbound := code.value.(int)
				bindings = bindings[:len(bindings)-unbound]
			case OP_REBIND:
				a := tc.pop()
				assertArgumentType(dtArray(a), dtArray(DATA_ANY), code, loc)

			// Intrinsics
			case OP_ASSEMBLY:
				var have []DataType
				var want []DataType
				val := value.(ASMValue)

				for i := val.argumentCount; i > 0; i-- {
					a := tc.pop()
					have = append([]DataType{a}, have...)
					want = append(want, DATA_ANY)
				}
				for i := 0; i < val.returnCount; i++ {
					tc.push(DATA_INT)
				}
			case OP_ADD, OP_SUBSTRACT:
				// TODO: Current supporting any as first argument, this might have to
				// change for type safety. But it allows to use parapoly.
				b := tc.pop()
				a := tc.pop()
				assertArgumentType(dtArray(a, b), dtArray(DATA_ANY, DATA_INT), code, loc)
				if a == DATA_INT && b == DATA_INT {
					tc.push(DATA_INT)
				} else if a == DATA_CHAR || b == DATA_CHAR {
					tc.push(DATA_CHAR)
				} else {
					tc.push(DATA_PTR)
				}
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
			case OP_MODULO:
				b := tc.pop()
				a := tc.pop()
				assertArgumentType(dtArray(a, b), dtArray(DATA_INT, DATA_INT), code, loc)
				tc.push(DATA_INT)
			case OP_EQUAL, OP_NOT_EQUAL, OP_GREATER, OP_GREATER_EQUAL, OP_LESS, OP_LESS_EQUAL:
				b := tc.pop()
				a := tc.pop()
				assertArgumentType(dtArray(a, b), dtArray(DATA_ANY, DATA_ANY), code, loc)
				tc.push(DATA_BOOL)
			case OP_FUNCTION_CALL:
				var have []DataType
				var want []DataType
				var fns []Function
				var funcRef Function

				calls := code.value.([]FunctionCall)

				for _, c := range calls {
					fns = append(fns, findFunctionByIP(c.ip))
				}

				if len(fns) == 1 {
					// We have found only one function with this signature.
					funcRef = fns[0]
				} else {
					// The function call is polymorphistic, we need to find the
					// one with the same signature and calling convention.
					for _, f := range fns {
						// To easily match the stack behavior, we first reverse it
						// (simulating we pop from it) and then shrink it to the number
						// of values expected in arguments (since stack simulation in
						// typechecking is not a dynamic array).
						var argTypes []DataType
						reverseStackOrder := tc.stackCount - len(f.arguments.types)
					    stackReversed := tc.stack[reverseStackOrder:]
						stackReducedToArgsLen := stackReversed[:len(f.arguments.types)]

						for _, d := range f.arguments.types {
							argTypes = append(argTypes, d.typ)
						}

						if reflect.DeepEqual(argTypes, stackReducedToArgsLen) {
							funcRef = f
							break
						}
					}
				}

				// We redefine the chunk value to match the function accordingly.
				// We do this while typechecking, so we can allow for polymorphism in
				// the parameters of the functions. Once we get here, we have found the
				// exact function according to the stack values provided.
				TheProgram.chunks[ifunction].code[icode].value =
					FunctionCall{name: funcRef.name, ip: funcRef.ip}

				// Doing parapoly initial checks. We go over the parameters, if parapoly
				// is enabled in this function, and then map each type of parameter that
				// expects inferred data. Once the correct types are mapped, we allow the
				// user to return a different order of definition from the original call,
				// and we make sure we maintain the type safety.
				var inferredTypes map[string]DataType
				inferredTypes = make(map[string]DataType)

				if funcRef.arguments.parapoly {
					reverseStackOrder := tc.stackCount - len(funcRef.arguments.types)
					stackReversed := tc.stack[reverseStackOrder:]

					for i, d := range funcRef.arguments.types {
						if d.typ == DATA_INFER {
							if inferredTypes[d.name] == DATA_NONE {
								inferredTypes[d.name] = stackReversed[i]
							}
						}
					}
				}

				for _, d := range funcRef.arguments.types {
					t := tc.pop()
					have = append([]DataType{t}, have...)
					want = append(want, d.typ)
				}

				assertArgumentType(have, want, code, loc)

				for _, d := range funcRef.returns.types {
					if d.typ == DATA_INFER {
						tc.push(inferredTypes[d.name])
					} else {
						tc.push(d.typ)
					}
				}

			case OP_IF_START:
				a := tc.pop()
				assertArgumentType(dtArray(a), dtArray(DATA_BOOL), code, loc)
				tc.scope++
				snapshots[tc.scope] = tc
			case OP_IF_END, OP_IF_ELSE:

			case OP_LOOP_END:
				tc.scope--
			case OP_LOOP_SETUP:
				// NOTE: This is just meant to be a label in the code.
			case OP_LOOP_START:
				a := tc.pop()
				assertArgumentType(dtArray(a), dtArray(DATA_BOOL), code, loc)
				tc.scope++

			case OP_RET:

			default:
				fmt.Println("Unhandled", code.op)
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

	for len(dce.funcsCalled) > 0 {
		ip := dce.pop()

		for i, _ := range TheProgram.chunks {
			function := &TheProgram.chunks[i]

			if function.ip == ip {
				function.called = true

				for _, c := range function.code {
					if c.op == OP_FUNCTION_CALL {
						newCall := c.value.(FunctionCall)
						f := findFunctionByIP(newCall.ip)

						if !f.called {
							dce.push(newCall.ip)
						}
					}
				}
			}
		}
	}
}
