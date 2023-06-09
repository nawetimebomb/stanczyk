package main

import (
	"fmt"
)

type Parser struct {
	previous Token
	current  Token
	tokens   []Token
	index    int
}

type Macro struct {
	word   string
	tokens []Token
}

type Scope struct {
	tt     TokenType
	thenIP int
	loopIP int
}

type Frontend struct {
	error   bool
	current	*Chunk
	macros  []Macro
	sLevel  int
	scope   [255]Scope
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
func startParser(filename string, source string) {
	parser.index = 0
	parser.tokens = TokenizeFile(filename, source)
	parser.current = parser.tokens[parser.index]
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
	frontend.current.Write(code)
}

func emitEndOfCode() {
	code := Code{
		op: OP_EOC,
	}

	emit(code)
}

/*   ___ ___ ___ ___ ___  ___   ___ ___ ___ ___  ___  ___
 *  | _ \ _ \ __| _ \ _ \/ _ \ / __| __/ __/ __|/ _ \| _ \
 *  |  _/   / _||  _/   / (_) | (__| _|\__ \__ \ (_) |   /
 *  |_| |_|_\___|_| |_|_\\___/ \___|___|___/___/\___/|_|_\
 */
func macroStatement() {
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

func preprocess(index int) {
	filename := file.filename[index]
	source := file.source[index]

	startParser(filename, source)

	for !check(TOKEN_EOF) {
		advance()
		switch parser.previous.typ {
		case TOKEN_MACRO: macroStatement()
		case TOKEN_USING:
			advance()
			file.Open(parser.previous.value.(string))
		}
	}
}

/*    ___ ___  __  __ ___ ___ _      _ _____ ___ ___  _  _
 *   / __/ _ \|  \/  | _ \_ _| |    /_\_   _|_ _/ _ \| \| |
 *  | (_| (_) | |\/| |  _/| || |__ / _ \| |  | | (_) | .` |
 *   \___\___/|_|  |_|_| |___|____/_/ \_\_| |___\___/|_|\_|
 */
func expandMacro(token Token) {
	word := token.value
	macroIndex := -1

	for x, m := range frontend.macros {
		if m.word == word {
			macroIndex = x
			break
		}
	}

	if macroIndex == -1 {
		errorAt(&token, MsgParseWordNotFound, word)
		return
	}

	for _, t := range frontend.macros[macroIndex].tokens {
		parseToken(t)
	}
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
	case TOKEN_SYSCALL3:
		code.op = OP_SYSCALL3
		emit(code)

	// Special
	case TOKEN_WORD:
		expandMacro(token)
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
			case TOKEN_LOOP:
				code.op = OP_LOOP
				code.value = cScope.loopIP
				emit(code)

				var endLoop Code
				endLoop.loc = token.loc
				endLoop.op = OP_END_LOOP
				emit(endLoop)
			}

			frontend.current.code[cScope.thenIP].value = len(frontend.current.code)
			*sLevel--
		} else {
			errorAt(&token, "TODO add error orphan dot")
		}
	}
}

func compile(index int) {
	filename := file.filename[index]
	source := file.source[index]

	startParser(filename, source)

	for !check(TOKEN_EOF) {
		advance()
		token := parser.previous

		switch token.typ {
		case TOKEN_USING:
			advance()
			continue
		case TOKEN_MACRO:
			jumpTo(token.value.(int))
			continue
		}

		parseToken(token)
	}
}

func FrontendRun(chunk *Chunk) {
	frontend.current = chunk

	// Core standard library
	file.Open("basics")

	// User entry file
	file.Open(Stanczyk.workspace.entry)

	for index := 0; index < len(file.filename); index++ {
		preprocess(index)
	}

	if frontend.error {
		ExitWithError(CodeParseError)
	}

	for index := 0; index < len(file.filename); index++ {
		compile(index)
	}

	if frontend.error {
		ExitWithError(CodeParseError)
	}

	emitEndOfCode()
}
