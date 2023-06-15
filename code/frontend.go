package main

import (
	"fmt"
)

type Parser struct {
	previous Token
	current  Token
	tokens   []Token
	index    int
	length   int
}

type Macro struct {
	word   string
	tokens []Token
}

type Frontend struct {
	error      bool
	current	   *Chunk
	macros     []Macro
	scopeLevel int
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
	loc := token.loc
	ReportParseError(msg, loc.f, loc.l, loc.c)
}

/*   ___  _   ___  ___ ___ ___
 *  | _ \/_\ | _ \/ __| __| _ \
 *  |  _/ _ \|   /\__ \ _||   /
 *  |_|/_/ \_\_|_\|___/___|_|_\
 */
func startParser(filename string, source string) {
	parser.index = 0
	parser.tokens = TokenizeFile(filename, source)
	parser.length = len(parser.tokens)
	parser.current = parser.tokens[parser.index]
}

func advance() {
	parser.index++
	parser.previous = parser.current
	parser.current = parser.tokens[parser.index]
}

func jump(index int) {
	parser.index = index
	parser.previous = parser.tokens[index - 1]
	parser.current = parser.tokens[index]
}

func consume(tt TokenType, err string) bool {
	if tt == parser.current.typ {
		advance()
		return true
	}

	errorAt(&parser.current, err)
	return false
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

	for !check(TOKEN_DOT) && !check(TOKEN_MACRO) && !check(TOKEN_EOF) {
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
		token := parser.previous

		switch token.typ {
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
	case TOKEN_DIV:
		code.op = OP_DIVIDE
		emit(code)
	case TOKEN_DROP:
		code.op = OP_DROP
		emit(code)
	case TOKEN_MINUS:
		code.op = OP_SUBSTRACT
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

	case TOKEN_USING:
		advance()
	case TOKEN_MACRO:
		jump(code.value.(int))
	}
}

func compile(index int) {
	filename := file.filename[index]
	source := file.source[index]

	startParser(filename, source)

	for !check(TOKEN_EOF) {
		advance()
		parseToken(parser.previous)
	}
}

func FrontendRun(chunk *Chunk) {
	frontend.current = chunk

	file.Open("basics")
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
