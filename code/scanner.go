package main

import (
	"bufio"
	"strconv"
	"strings"
)

type TokenType int

const (
	// Constants
	TOKEN_INT TokenType = iota
	TOKEN_STR

	// Reserved Words
	TOKEN_BANG_EQUAL
	TOKEN_DIV
	TOKEN_DO
	TOKEN_DOT
	TOKEN_DROP
	TOKEN_DUP
	TOKEN_ELSE
	TOKEN_EQUAL
	TOKEN_FALSE
	TOKEN_GREATER
	TOKEN_GREATER_EQUAL
	TOKEN_IF
	TOKEN_LESS
	TOKEN_LESS_EQUAL
	TOKEN_LOOP
	TOKEN_MACRO
	TOKEN_MINUS
	TOKEN_PLUS
	TOKEN_PRINT
	TOKEN_STAR
	TOKEN_SWAP
	TOKEN_SYSCALL3
	TOKEN_TRUE
	TOKEN_USING

	// Specials
	TOKEN_EOF
	TOKEN_WORD
)

type reserved struct {
	name string
	typ  TokenType
}

var reservedWords = [24]reserved{
	reserved{typ: TOKEN_PLUS,			name: "+"		},
	reserved{typ: TOKEN_MINUS,			name: "-"		},
	reserved{typ: TOKEN_STAR,			name: "*"		},
	reserved{typ: TOKEN_DOT,			name: "."		},
	reserved{typ: TOKEN_EQUAL,			name: "="		},
	reserved{typ: TOKEN_BANG_EQUAL,		name: "!="		},
	reserved{typ: TOKEN_GREATER,		name: ">"		},
	reserved{typ: TOKEN_GREATER_EQUAL,	name: ">="		},
	reserved{typ: TOKEN_LESS,			name: "<"		},
	reserved{typ: TOKEN_LESS_EQUAL,		name: "<="		},
	reserved{typ: TOKEN_DIV,			name: "div"		},
	reserved{typ: TOKEN_DO,				name: "do"		},
	reserved{typ: TOKEN_DROP,			name: "drop"	},
	reserved{typ: TOKEN_DUP,			name: "dup"		},
	reserved{typ: TOKEN_ELSE,			name: "else"	},
	reserved{typ: TOKEN_FALSE,			name: "false"	},
	reserved{typ: TOKEN_IF,				name: "if"		},
	reserved{typ: TOKEN_LOOP,			name: "loop"	},
	reserved{typ: TOKEN_MACRO,			name: "macro"	},
	reserved{typ: TOKEN_PRINT,			name: "print"	},
	reserved{typ: TOKEN_SWAP,			name: "swap"	},
	reserved{typ: TOKEN_SYSCALL3,		name: "syscall3"},
	reserved{typ: TOKEN_TRUE,			name: "true"	},
	reserved{typ: TOKEN_USING,			name: "using"	},
}

type Location struct {
	f string
	c int
	l int
}

type Token struct {
	typ   TokenType
	loc   Location
	value any
}

type Scanner struct {
	filename string
	source   string
	column   int
	line     int
	tokens   []Token
}

var scanner Scanner

func makeToken(t TokenType, value ...any) {
	var token Token
	token.typ = t
	token.loc = Location{
		f: scanner.filename,
		c: scanner.column,
		l: scanner.line,
	}

	if value != nil {
		token.value = value[0]
	}

	scanner.tokens = append(scanner.tokens, token)
}

func makeNumber(c byte, line string, index *int) {
	result := string(c)

	for Advance(&c, line, index) && IsDigit(c) {
		result += string(c)
	}

	value, _ := strconv.Atoi(result)
	makeToken(TOKEN_INT, value)
}

func makeString(c byte, line string, index *int) {
	result := ""

	for Advance(&c, line, index) && c != '"' {
		result += string(c)
	}

	makeToken(TOKEN_STR, result)
}

func makeWord(c byte, line string, index *int) {
	word := string(c)

	for Advance(&c, line, index) && c != ' ' {
		word += string(c)
	}

	for _, reserved := range reservedWords {
		if reserved.name == word {
			makeToken(reserved.typ)
			return
		}
	}

	makeToken(TOKEN_WORD, word)
}

func crossRefMacros() {
	scope := 0
	macroIndex := -1

	for index, token := range scanner.tokens {
		tt := token.typ

		switch {
		case tt == TOKEN_MACRO:
			scope++
			macroIndex = index
		case tt == TOKEN_IF, tt == TOKEN_LOOP:
			scope++
		case tt == TOKEN_DOT:
			if scope > 0 {
				scope--
				if scope == 0 && macroIndex != -1 {
					scanner.tokens[macroIndex].value = index
					macroIndex = -1
			 	}
			} else {
				ReportErrorAtLocation(MsgParseMacroMissingDot, token.loc)
				ExitWithError(CodeParseError)
			}
		}
	}
}

func TokenizeFile(f string, s string) []Token {
	scanner.filename = f
	scanner.source = s
	scanner.column = 0
	scanner.line = 1
	scanner.tokens = make([]Token, 0, 32)

	b := bufio.NewScanner(strings.NewReader(scanner.source))
	b.Split(bufio.ScanLines)

	for b.Scan() {
		line := b.Text()

		for index := 0; index < len(line); index++ {
			c := line[index]
			scanner.column = index
			if (c == ' ') {
				continue
			}

			switch {
			case c == '"':
				makeString(c, line, &index)
			case IsDigit(c):
				makeNumber(c, line, &index)
			default:
				makeWord(c, line, &index)
			}
		}

		scanner.line++
		scanner.column = 0
	}

	makeToken(TOKEN_EOF)

	crossRefMacros()

	return scanner.tokens
}
