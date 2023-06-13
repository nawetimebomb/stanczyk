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

	// Types
	TOKEN_DTYPE_BOOL
	TOKEN_DTYPE_INT
	TOKEN_DTYPE_PTR

	// Reserved Words
	TOKEN_BANG_EQUAL
	TOKEN_CONST
	TOKEN_DIV
	TOKEN_DO
	TOKEN_DOT
	TOKEN_DROP
	TOKEN_DUP
	TOKEN_ELSE
	TOKEN_EQUAL
	TOKEN_FALSE
	TOKEN_FUNCTION
	TOKEN_FUNCTION_STAR
	TOKEN_GREATER
	TOKEN_GREATER_EQUAL
	TOKEN_IF
	TOKEN_LESS
	TOKEN_LESS_EQUAL
	TOKEN_LOOP
	TOKEN_MACRO
	TOKEN_MINUS
	TOKEN_OVER
	TOKEN_PLUS
	TOKEN_PRINT
	TOKEN_RET
	TOKEN_RIGHT_ARROW
	TOKEN_STAR
	TOKEN_SWAP
	TOKEN_TRUE
	TOKEN_USING

	// Specials
	TOKEN_EOF
	TOKEN_WORD
)

type reserved struct {
	word  string
	typ   TokenType
}

var reservedWords = [32]reserved{
	reserved{typ: TOKEN_BANG_EQUAL,		word: "!="		  },
	reserved{typ: TOKEN_CONST,   		word: "const"	  },
	reserved{typ: TOKEN_DIV,			word: "div"		  },
	reserved{typ: TOKEN_DO,				word: "do"		  },
	reserved{typ: TOKEN_DOT,			word: "."		  },
	reserved{typ: TOKEN_DROP,			word: "drop"	  },
	reserved{typ: TOKEN_DTYPE_BOOL,     word: "bool"      },
	reserved{typ: TOKEN_DTYPE_INT,      word: "int"       },
	reserved{typ: TOKEN_DTYPE_PTR,      word: "ptr"       },
	reserved{typ: TOKEN_DUP,			word: "dup"		  },
	reserved{typ: TOKEN_ELSE,			word: "else"	  },
	reserved{typ: TOKEN_EQUAL,			word: "="		  },
	reserved{typ: TOKEN_FALSE,			word: "false"	  },
	reserved{typ: TOKEN_FUNCTION,		word: "function"  },
	reserved{typ: TOKEN_FUNCTION_STAR,	word: "function*" },
	reserved{typ: TOKEN_GREATER,		word: ">"		  },
	reserved{typ: TOKEN_GREATER_EQUAL,	word: ">="		  },
	reserved{typ: TOKEN_IF,				word: "if"		  },
	reserved{typ: TOKEN_LESS,			word: "<"		  },
	reserved{typ: TOKEN_LESS_EQUAL,		word: "<="		  },
	reserved{typ: TOKEN_LOOP,			word: "loop"	  },
	reserved{typ: TOKEN_MACRO,			word: "macro"	  },
	reserved{typ: TOKEN_MINUS,			word: "-"		  },
	reserved{typ: TOKEN_OVER,           word: "over"	  },
	reserved{typ: TOKEN_PLUS,			word: "+"		  },
	reserved{typ: TOKEN_PRINT,			word: "print"	  },
	reserved{typ: TOKEN_RET,            word: "ret"   	  },
	reserved{typ: TOKEN_RIGHT_ARROW,    word: "->"   	  },
	reserved{typ: TOKEN_STAR,			word: "*"		  },
	reserved{typ: TOKEN_SWAP,			word: "swap"	  },
	reserved{typ: TOKEN_TRUE,			word: "true"	  },
	reserved{typ: TOKEN_USING,			word: "using"	  },
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
		if reserved.word == word {
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
		case tt == TOKEN_CONST, tt == TOKEN_IF, tt == TOKEN_LOOP,
			tt == TOKEN_FUNCTION, tt == TOKEN_FUNCTION_STAR:
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
