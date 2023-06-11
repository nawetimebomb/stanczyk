package main

import (
	"fmt"
)

type ScopeName int

const (
	SCOPE_PROGRAM ScopeName = iota
	SCOPE_FUNCTION
)

type Parser struct {
	previous Token
	current  Token
	tokens   []Token
	internal bool
	index    int
}

type Macro struct {
	word   string
	tokens []Token
}

type Scope struct {
	tt       TokenType
	thenIP   int
	loopIP   int
}

type Frontend struct {
	words     []string
	error     bool
	current	  *Function
	macros    []Macro
	sLevel    int
	sName     ScopeName
	scope     [10]Scope
}

var file FileManager
var frontend Frontend
var parser Parser

/*   ___ ___ ___  ___  ___  ___
 *  | __| _ \ _ \/ _ \| _ \/ __|
 *  | _||   /   / (_) |   /\__ \
 *  |___|_|_\_|_\\___/|_|_\|___/
 */
func errorAt(token *Token, format string, values ...any) {
	frontend.error = true

	msg := fmt.Sprintf(format, values...)
	ReportErrorAtLocation(msg, token.loc)
}

/*   ___  _   ___  ___ ___ ___
 *  | _ \/_\ | _ \/ __| __| _ \
 *  |  _/ _ \|   /\__ \ _||   /
 *  |_|/_/ \_\_|_\|___/___|_|_\
 */
func startParser(f File) {
	parser.index = 0
	parser.tokens = TokenizeFile(f.filename, f.source)
	parser.current = parser.tokens[parser.index]
	parser.internal = f.internal
}

func advance() {
	parser.index++
	parser.previous = parser.current
	parser.current = parser.tokens[parser.index]
}

func jumpTo(index int) {
	parser.index = index
	parser.current = parser.tokens[index]
	advance()
}

func consume(tt TokenType, err string) {
	if tt == parser.current.typ {
		advance()
		return
	}

	errorAt(&parser.current, err)
}

func check(tt TokenType) bool {
	result := tt == parser.current.typ
	return result
}

func match(tt TokenType) bool {
    if !check(tt) {
		return false;
	}
    advance();
    return true;
}

/*   ___ ___
 *  |_ _| _ \
 *   | ||   /
 *  |___|_|_\
 */
func emit(code Code) {
	frontend.current.WriteCode(code)
}

func emitReturn() {
	emit(Code{
		op: OP_RET,
		loc: parser.previous.loc,
		value: 0,
	})
}

/*   ___ ___ ___ ___ ___  ___   ___ ___ ___ ___  ___  ___
 *  | _ \ _ \ __| _ \ _ \/ _ \ / __| __/ __/ __|/ _ \| _ \
 *  |  _/   / _||  _/   / (_) | (__| _|\__ \__ \ (_) |   /
 *  |_| |_|_\___|_| |_|_\\___/ \___|___|___/___/\___/|_|_\
 */
func newMacro() {
	var macro Macro
	endOfMacroIndex := parser.previous.value.(int)

	if !match(TOKEN_WORD) {
		errorAt(&parser.previous, MsgParseMacroMissingWord)
		return
	}

	macro.word = parser.previous.value.(string)

	consume(TOKEN_DO, MsgParseMacroMissingDo)

	if match(TOKEN_DOT) {
		errorAt(&parser.previous, MsgParseMacroMissingContent)
		return
	}

	for parser.index < endOfMacroIndex {
		advance()
		macro.tokens = append(macro.tokens, parser.previous)
	}

	frontend.macros = append(frontend.macros, macro)

	consume(TOKEN_DOT, MsgParseMacroMissingDot)
}

func newFunction(token Token) {
	var function Function
	emitSyscall := token.typ == TOKEN_FUNCTION_STAR
	function.ip = len(TheProgram.chunks)
	function.loc = token.loc
	function.internal = parser.internal
	frontend.current = &function

	if !match(TOKEN_WORD) {
		errorAt(&token, MsgParseFunctionMissingName)
		ExitWithError(CodeParseError)
	}

	word := parser.previous
	name := word.value.(string)

	function.name = name

	if !check(TOKEN_RIGHT_ARROW) && !check(TOKEN_DO) {
		for !check(TOKEN_RIGHT_ARROW) && !check(TOKEN_DO) && !check(TOKEN_EOF) {
			advance()
			t := parser.previous
			targ := DATA_EMPTY

			switch t.typ {
			case TOKEN_DTYPE_BOOL: targ = DATA_BOOL
			case TOKEN_DTYPE_INT:  targ = DATA_INT
			case TOKEN_DTYPE_PTR:  targ = DATA_PTR
			default:
				msg := fmt.Sprintf(MsgParseFunctionUnknownType, t.value)
				errorAt(&t, msg)
				ExitWithError(CodeParseError)
			}

			function.args = append(function.args, targ)
		}
	}

	if match(TOKEN_RIGHT_ARROW) {
		if check(TOKEN_DO) {
			errorAt(&parser.previous, MsgParseFunctionNoReturnSpecified)
		}

		for !check(TOKEN_DO) {
			advance()
			t := parser.previous
			tret := DATA_EMPTY

			switch t.typ {
			case TOKEN_DTYPE_BOOL: tret = DATA_BOOL
			case TOKEN_DTYPE_INT: tret = DATA_INT
			case TOKEN_DTYPE_PTR: tret = DATA_PTR
			default:
				msg := fmt.Sprintf(MsgParseFunctionUnknownType, t.value)
				errorAt(&t, msg)
				ExitWithError(CodeParseError)
			}

			function.rets = append(function.rets, tret)
		}
	}

	consume(TOKEN_DO, MsgParseFunctionMissingDo)

	frontend.sLevel++
	frontend.scope[1].tt = TOKEN_FUNCTION

	for frontend.sLevel > 0 && !check(TOKEN_EOF) {
		advance()
		parseToken(parser.previous)
	}

	if emitSyscall {
		emit(Code{
			op: OP_SYSCALL,
			loc: function.loc,
		})
	}

	emitReturn()

	TheProgram.chunks = append(TheProgram.chunks, function)
}

func compile(index int) {
	f := file.files[index]

	startParser(f)

	for !check(TOKEN_EOF) {
		advance()
		token := parser.previous
		switch token.typ {
		case TOKEN_MACRO:
			newMacro()
		case TOKEN_USING:
			advance()
			file.Open(parser.previous.value.(string))
		case TOKEN_FUNCTION, TOKEN_FUNCTION_STAR:
			newFunction(token)
		default:
			ReportErrorAtLocation(MsgParseErrorProgramScope, token.loc)
			ExitWithError(CodeParseError)
		}
	}
}

/*    ___ ___  __  __ ___ ___ _      _ _____ ___ ___  _  _
 *   / __/ _ \|  \/  | _ \_ _| |    /_\_   _|_ _/ _ \| \| |
 *  | (_| (_) | |\/| |  _/| || |__ / _ \| |  | | (_) | .` |
 *   \___\___/|_|  |_|_| |___|____/_/ \_\_| |___\___/|_|\_|
 */
func expandMacro(index int) {
	for _, t := range frontend.macros[index].tokens {
		parseToken(t)
	}
}

func expandWord(token Token) {
	addWord(token)
	word := token.value

	for x, m := range frontend.macros {
		if m.word == word {
			expandMacro(x)
			return
		}
	}

	emit(Code{ op: OP_WORD, loc: token.loc, value: word,})
}

func addWord(token Token) {
	word := token.value.(string)
	for _, w := range frontend.words {
		if w == word {
			return
		}
	}
	frontend.words = append(frontend.words, word)
}

func parseToken(token Token) {
	var code Code
	code.loc = token.loc
	code.value = token.value
	sLevel := &frontend.sLevel

	switch token.typ {
	// Constants
	case TOKEN_FALSE:
		code.op = OP_PUSH_BOOL
		code.value = 0
		emit(code)
	case TOKEN_INT:
		code.op = OP_PUSH_INT
		emit(code)
	case TOKEN_STR:
		code.op = OP_PUSH_STR
		emit(code)
	case TOKEN_TRUE:
		code.op = OP_PUSH_BOOL
		code.value = 1
		emit(code)

	// Intrinsics
	case TOKEN_BANG_EQUAL:
		code.op = OP_NOT_EQUAL
		emit(code)
	case TOKEN_DIV:
		code.op = OP_DIVIDE
		emit(code)
	case TOKEN_DROP:
		code.op = OP_DROP
		emit(code)
	case TOKEN_DUP:
		code.op = OP_DUP
		emit(code)
	case TOKEN_EQUAL:
		code.op = OP_EQUAL
		emit(code)
	case TOKEN_GREATER:
		code.op = OP_GREATER
		emit(code)
	case TOKEN_GREATER_EQUAL:
		code.op = OP_GREATER_EQUAL
		emit(code)
	case TOKEN_LESS:
		code.op = OP_LESS
		emit(code)
	case TOKEN_LESS_EQUAL:
		code.op = OP_LESS_EQUAL
		emit(code)
	case TOKEN_MINUS:
		code.op = OP_SUBSTRACT
		emit(code)
	case TOKEN_OVER:
		code.op = OP_OVER
		emit(code)
	case TOKEN_PLUS:
		code.op = OP_ADD
		emit(code)
	case TOKEN_PRINT:
		code.op = OP_PRINT
		emit(code)
	case TOKEN_STAR:
		code.op = OP_MULTIPLY
		emit(code)
	case TOKEN_SWAP:
		code.op = OP_SWAP
		emit(code)

	// Special
	case TOKEN_WORD:
		expandWord(token)
	case TOKEN_IF:
		*sLevel++
		frontend.scope[*sLevel].tt = token.typ
		code.op = OP_IF
		emit(code)
	case TOKEN_ELSE:
		if *sLevel > 0 {
			prevThen := frontend.scope[*sLevel].thenIP
			frontend.scope[*sLevel].thenIP = len(frontend.current.code)
			code.op = OP_JUMP
			emit(code)
			frontend.current.code[prevThen].value = len(frontend.current.code)
		} else {
			errorAt(&token, MsgParseElseOrphanTokenFound)
		}
	case TOKEN_LOOP:
		*sLevel++
		frontend.scope[*sLevel].tt = token.typ
		frontend.scope[*sLevel].loopIP = len(frontend.current.code)
	case TOKEN_DO:
		if *sLevel > 0 {
			frontend.scope[*sLevel].thenIP = len(frontend.current.code)
			code.op = OP_JUMP_IF_FALSE
			emit(code)
		} else {
			errorAt(&token, MsgParseDoOrphanTokenFound)
		}
	case TOKEN_DOT:
		if *sLevel > 0 {
			cScope := frontend.scope[*sLevel]

			switch cScope.tt {
			case TOKEN_IF:
				code.op = OP_END_IF
				emit(code)
				frontend.current.code[cScope.thenIP].value = len(frontend.current.code)
			case TOKEN_LOOP:
				code.op = OP_LOOP
				code.value = cScope.loopIP
				emit(code)

				var endLoop Code
				endLoop.loc = token.loc
				endLoop.op = OP_END_LOOP
				emit(endLoop)
				frontend.current.code[cScope.thenIP].value = len(frontend.current.code)
			}

			*sLevel--
		} else {
			errorAt(&token, MsgParseDotOrphanTokenFound)
		}
	}
}

func FrontendRun() {
	// Core standard library
	file.Open("basics")

	// User entry file
	file.Open(Stanczyk.workspace.entry)

	for index := 0; index < len(file.files); index++ {
		compile(index)
	}

	for index := 0; index < len(TheProgram.chunks); index++ {
		f := &TheProgram.chunks[index]

		if f.name == "main" {
			f.called = true
		}

		if Contains(frontend.words, f.name) {
			f.called = true
		}
	}

	if frontend.error {
		ExitWithError(CodeParseError)
	}
}
