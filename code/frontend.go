package main

import (
	"fmt"
)

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

func errorAt(token *Token, format string, values ...any) {
	frontend.error = true

	msg := fmt.Sprintf(format, values...)
	loc := token.loc
	ReportParseError(msg, loc.f, loc.l, loc.c)
}

func emit(code Code) {
	frontend.current.Write(code)
}

func emitEndOfCode() {
	code := Code{
		op: OP_EOC,
	}

	emit(code)
}

func findNextDotIndex(tokens []Token, startingIndex int) int {
	for index := startingIndex; index < len(tokens); index++ {
		t := tokens[index]

		if t.typ == TOKEN_DOT {
			return index
		}
	}

	return -1
}

func saveMacro(tokens []Token) {
	var macro Macro
	if tokens[1].typ != TOKEN_WORD {
		fmt.Println("Token is not a word ", tokens[1])
	}
	macro.word = tokens[1].value.(string)

	if tokens[2].typ != TOKEN_DO {
		fmt.Println("Token is not do ", tokens[2])
	}

	for _, t := range tokens[3:] {
		macro.tokens = append(macro.tokens, t)
	}

	frontend.macros = append(frontend.macros, macro)
}

func preprocess(index int) {
	filename := file.filename[index]
	source := file.source[index]
	tokens := TokenizeFile(filename, source)

	for index := 0; index < len(tokens); index++ {
		token := tokens[index]

		switch token.typ {
		case TOKEN_MACRO:
			endIndex := findNextDotIndex(tokens, index)
			if (endIndex == -1) {
				// TODO: Add error
			}
			saveMacro(tokens[index:endIndex])
			index = endIndex
		case TOKEN_USING:
			index++
			token = tokens[index]
			file.Open(token.value.(string))
		}
	}
}

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
	} else {
		for _, t := range frontend.macros[macroIndex].tokens {
			parseToken(t)
		}
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
	}
}

func compile(index int) {
	filename := file.filename[index]
	source := file.source[index]
	tokens := TokenizeFile(filename, source)

	skipNext := false
	skipUntilBlockEnds := false

	for _, token := range tokens {
		// TODO: There should be a way where I just parse this by block reference
		if skipNext {
			skipNext = false
			continue
		}

		if token.typ == TOKEN_MACRO {
			skipUntilBlockEnds = true
			continue
		}

		if token.typ == TOKEN_DOT && skipUntilBlockEnds {
			skipUntilBlockEnds = false
			continue
		}

		if skipUntilBlockEnds {
			continue
		}

		if token.typ == TOKEN_USING {
			skipNext = true
			continue
		}

		parseToken(token)
	}
}

func FrontendRun(chunk *Chunk) {
	frontend.current = chunk

	file.Open("basics")
	file.Open(Stanczyk.workspace.entry)

	for index := 0; index < len(file.filename); index++ {
		preprocess(index)
	}

	for index := 0; index < len(file.filename); index++ {
		compile(index)
	}

	emitEndOfCode()

	if frontend.error {
		ExitWithError(CodeParseError)
	}
}
