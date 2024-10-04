package skc

import (
	"fmt"
	"reflect"
	"strconv"
	"strings"
)

type ScopeType int

const (
	SCOPE_GLOBAL = iota
	SCOPE_FUNCTION
	SCOPE_LOOP
)

type BindType int

const (
	CONSTANT BindType = iota
	VARIABLE
	BIND
	AUTOBIND
)

type AutobindValue string

const (
	NONE AutobindValue = ""
	LOOPINDEX = "LOOPINDEX"
	LOOPLIMIT = "LOOPLIMIT"
)

type Let struct {
	bindId  int
	scopeId int

	btype   BindType
	dtype   DataType
	name    string
	token   Token
	value   any
}

type LoopScopeValue struct {
	bindIndexId int
	bindLimitId int
}

type Scope struct {
	binds          []Let
	scopeId        int
	startCondition ScopeStartCondition
	startIP        int
	startToken     Token
	typ            ScopeType
	value          any
}

type ScopeContainer struct {
	levels        []Scope
	currentLevel  int
}

type ScopeOld struct {
	typ           ScopeType
	tt            TokenType
	loopCondition ScopeStartCondition
	startIP       int
	thenIP        int
	loopIP        int
}

type Object struct {
	id    int
	value int
	word  string
}

type Frontend struct {
	constants  []Object
	variables  []Object
	current	   *Function
	error      bool
	sLevel     int
	scopeOld   [10]ScopeOld
	scope      ScopeContainer
}

type Parser struct {
	previous Token
	current  Token
	tokens   []Token
	internal bool
	index    int
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
	return tt == parser.current.typ
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
func startScope(newScope Scope) *Scope {
	newScope.scopeId = frontend.scope.currentLevel
	frontend.scope.levels = append(frontend.scope.levels, newScope)
	frontend.scope.currentLevel++
	return getCurrentScope()
}

func getCurrentScope() *Scope {
	return &frontend.scope.levels[frontend.scope.currentLevel-1]
}

func getCountForScopeType(typ ScopeType) int {
	count := 0

	for _, s := range frontend.scope.levels {
		if s.typ == typ {
			count++
		}
	}

	return count
}

func endScope() {
	frontend.scope.currentLevel--
	frontend.scope.levels = frontend.scope.levels[:len(frontend.scope.levels)-1]
}

func bind(newBind Let) {
	scope := getCurrentScope()
	newBind.bindId = len(scope.binds)
	newBind.scopeId = scope.scopeId
	scope.binds = append(scope.binds, newBind)
}

func getBound(token Token) (Let, bool) {
	word := token.value.(string)

	for index := frontend.scope.currentLevel-1; index >= 0; index-- {
		scope := frontend.scope.levels[index]

		for _, b := range scope.binds {
			if b.name == word {
				return b, true
			}
		}
	}

	return Let{}, false
}

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
func registerConstant(token Token) {
	var constant Object
	var tokens []Token

	if !match(TOKEN_WORD) {
		errorAt(&parser.previous, MsgParseConstMissingWord)
		return
	}

	wordToken := parser.previous
	constant.id = len(frontend.constants)
	constant.word = wordToken.value.(string)

	// TODO: Support rebiding constants in same scope if build configuration allows for it.
	_, found := getBound(wordToken)

	if found {
		msg := fmt.Sprintf(MsgParseConstOverrideNotAllowed, constant.word)
		errorAt(&token, msg)
		return
	}

	if match(TOKEN_PAREN_CLOSE) {
		msg := fmt.Sprintf(MsgParseConstInvalidContent, constant.word)
		errorAt(&token, msg)
	}

	if match(TOKEN_PAREN_OPEN) {
		for !check(TOKEN_PAREN_CLOSE) && !check(TOKEN_EOF) {
			advance()
			tokens = append(tokens, parser.previous)
		}

		if len(tokens) > 3 || len(tokens) == 2 {
			msg := fmt.Sprintf(MsgParseConstInvalidContent, constant.word)
			errorAt(&token, msg)
			return
		} else if len(tokens) == 3 {
			left := tokens[0].value.(int)
			right := tokens[1].value.(int)

			switch tokens[2].typ {
			case TOKEN_PLUS: constant.value = left + right
			case TOKEN_STAR: constant.value = left * right
			}
		} else if len(tokens) == 1 {
			constant.value = tokens[0].value.(int)
		}

		consume(TOKEN_PAREN_CLOSE, MsgParseConstMissingCloseStmt)
	} else {
		advance()
		constant.value = parser.previous.value.(int)
	}

	frontend.constants = append(frontend.constants, constant)
	bind(Let{
		btype: CONSTANT,
		dtype: DATA_INT,
		name: constant.word,
		token: token,
		value: constant.value,
	})
}

func registerFunction(token Token) {
	var function Function

	function.internal = parser.internal
	function.ip = len(TheProgram.chunks)
	function.loc = token.loc
	function.parsed = false

	if !match(TOKEN_WORD) {
		errorAt(&token, MsgParseFunctionMissingName)
		ExitWithError(CodeParseError)
	}

	tokenWord := parser.previous
	function.name = tokenWord.value.(string)

	if function.name == "main" {
		for _, f := range TheProgram.chunks {
			if f.name == "main" {
				msg := fmt.Sprintf(MsgParseFunctionMainAlreadyDefined,
					GetRelativePath(f.loc.f), f.loc.l)
				errorAt(&token, msg)
				ExitWithError(CodeParseError)
			}
		}
	}

	consume(TOKEN_PAREN_OPEN, MsgParseFunctionMissingOpenStmt)

	parsingArguments := true

	for !check(TOKEN_PAREN_CLOSE) && !check(TOKEN_EOF) {
		advance()
		t := parser.previous

		if t.typ == TOKEN_DASH_DASH_DASH {
			parsingArguments = false
			continue
		}

		parseArityInFunction(t, &function, parsingArguments)
	}

	consume(TOKEN_PAREN_CLOSE, MsgParseFunctionMissingCloseStmt)

	// Verify if the function signature is different from a previous function declared
	// with the same name. Error out if it matches signature arguments, or if it has different
	// return values.
	fcode, found := getFunction(tokenWord)

	if found {
		for _, fc := range fcode.value.([]FunctionCall) {
			f := TheProgram.chunks[fc.ip]

			if reflect.DeepEqual(f.arguments, function.arguments) {
				msg := fmt.Sprintf(MsgParseArityArgumentSameSignatureError,
					GetRelativePath(f.loc.f), f.loc.l)
				errorAt(&tokenWord, msg)
				ExitWithError(CodeParseError)
			}

			if !reflect.DeepEqual(f.returns, function.returns) {
				msg := fmt.Sprintf(MsgParseArityReturnDifferentSignatureError,
					GetRelativePath(f.loc.f), f.loc.l)
				errorAt(&tokenWord, msg)
				ExitWithError(CodeParseError)
			}
		}
	}

	// Skip the function content, since we're just registering it.
	for !check(TOKEN_RET) && !check(TOKEN_EOF) {
		advance()
	}

	consume(TOKEN_RET, MsgParseFunctionMissingRetWord)

	TheProgram.chunks = append(TheProgram.chunks, function)
}

func registerVar(token Token) {
	var variable Object
	if !match(TOKEN_WORD) {
		errorAt(&token, MsgParseVarMissingWord)
		ExitWithError(CodeParseError)
	}
	variable.id = len(frontend.variables)
	variable.word = parser.previous.value.(string)

	for _, v := range frontend.variables {
		if v.word == variable.word {
			msg := fmt.Sprintf(MsgParseVarOverrideNotAllowed, variable.word)
			errorAt(&parser.previous, msg)
			ExitWithError(CodeParseError)
		}
	}

	advance()
	vt := parser.previous

	switch vt.typ {
	case TOKEN_WORD:
		found := false
		for _, c := range frontend.constants {
			if c.word == vt.value {
				found = true
				variable.value = c.value
				break
			}
		}

		if !found {
			msg := fmt.Sprintf(MsgParseVarValueIsNotConst, vt.value)
			errorAt(&vt, msg)
			ExitWithError(CodeParseError)
		}
	case TOKEN_INT:
		variable.value = vt.value.(int)
	default:
		errorAt(&parser.previous, MsgParseVarMissingValue)
		ExitWithError(CodeParseError)
	}

	frontend.variables = append(frontend.variables, variable)
}

/*    ___ ___  __  __ ___ ___ _      _ _____ ___ ___  _  _
 *   / __/ _ \|  \/  | _ \_ _| |    /_\_   _|_ _/ _ \| \| |
 *  | (_| (_) | |\/| |  _/| || |__ / _ \| |  | | (_) | .` |
 *   \___\___/|_|  |_|_| |___|____/_/ \_\_| |___\___/|_|\_|
 */
func getConstant(token Token) (Code, bool) {
	word := token.value.(string)

	for _, c := range frontend.constants {
		if c.word == word {
			return Code{op: OP_PUSH_INT, loc: token.loc, value: c.value}, true
		}
	}

	return Code{}, false
}

func getVariable(token Token) (Code, bool) {
	word := token.value.(string)

	for _, v := range frontend.variables {
		if v.word == word {
			return Code{op: OP_PUSH_PTR, loc: token.loc, value: v}, true
		}
	}

	return Code{}, false
}

func getFunction(token Token) (Code, bool) {
	var val []FunctionCall
	word := token.value.(string)

	for _, f := range TheProgram.chunks {
		if f.name == word {
			val = append(val, FunctionCall{name: f.name, ip: f.ip})
		}
	}

	if len(val) > 0 {
		return Code{op: OP_FUNCTION_CALL, loc: token.loc, value: val}, true
	}

	return Code{}, false
}

func expandWord(token Token) {
	word := token.value.(string)

	for index, bind := range frontend.current.scope.binds {
		if bind == word {
			emit(Code{op: OP_PUSH_BIND, loc: token.loc, value: index})
			return
		}
	}

	b, found := getBound(token)

	if found {
		switch b.btype {
		case AUTOBIND, BIND:
			emit(Code{op: OP_PUSH_BOUND, loc: token.loc, value: b.value})
		case CONSTANT:
			emit(Code{op: OP_PUSH_INT, loc: token.loc, value: b.value.(int)})
		}

		return
	}

	// Find the word in variables. If it returns one, emit it.
	code_v, ok_v := getVariable(token)

	if ok_v {
		emit(code_v)
		return
	}

	// Find the word in functions. If it returns one, emit it
	code_f, ok_f := getFunction(token)

	if ok_f {
		emit(code_f)
		return
	}

	// If nothing has been found, emit the error.
	msg := fmt.Sprintf(MsgParseWordNotFound, token.value.(string))
	ReportErrorAtLocation(msg, token.loc)
	ExitWithError(CodeCodegenError)
}

func addAssembly(token Token) {
	var value Assembly

	code := Code{op: OP_ASSEMBLY, loc: token.loc}

	for !check(TOKEN_RIGHT_ARROW) && !check(TOKEN_PAREN_OPEN) && !check(TOKEN_EOF) {
		advance()
		parseArityInAssembly(parser.previous, &value.arguments)
	}

	if match(TOKEN_RIGHT_ARROW) {
		for !check(TOKEN_PAREN_OPEN) && !check(TOKEN_EOF) {
			advance()
			parseArityInAssembly(parser.previous, &value.returns)
		}
	}

	consume(TOKEN_PAREN_OPEN, MsgParseAssemblyMissingOpenStmt)

	var line []string

	for !check(TOKEN_PAREN_CLOSE) && !check(TOKEN_EOF) {
		advance()
		t := parser.previous
		nt := parser.current

		var val string

		switch t.typ {
		case TOKEN_WORD:
			val = t.value.(string)

			code_c, ok_c := getConstant(t)

			if ok_c {
				val = strconv.Itoa(code_c.value.(int))
			}

		case TOKEN_INT: val = strconv.Itoa(t.value.(int))
		}

		line = append(line, val)

		// If current parsed token (parser.previous) is not on the same line than
		// the next token, consider it an ASM line and push it over the Assembly.value OP,
		// then reset the line variable, so we can safely construct the next ASM line.
		if t.loc.l != nt.loc.l {
			// TODO: Should validate line construction here, with a function in extern.go
			// The validation should check for the following:
			//   1. Validate line[0] is a valid instruction
			//   2. Validate the next elements in the array (1, 2, ...) matches the
			//      rules for the instruction in line[0]
			value.body = append(value.body, strings.Join(line, " "))
			line = make([]string, 0, 0)
		}
	}

	consume(TOKEN_PAREN_CLOSE, MsgParseAssemblyMissingCloseStmt)
	code.value = value
	emit(code)
}

func parseToken(token Token) {
	var code Code
	code.loc = token.loc
	code.value = token.value
	sLevel := &frontend.sLevel

	switch token.typ {
	// Constants
	case TOKEN_CHAR:
		code.op = OP_PUSH_CHAR
		emit(code)
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

	// Casting
	case TOKEN_DTYPE_BOOL:
		code.op = OP_CAST
		code.value = DATA_BOOL
		emit(code)
	case TOKEN_DTYPE_CHAR:
		code.op = OP_CAST
		code.value = DATA_CHAR
		emit(code)
	case TOKEN_DTYPE_INT:
		code.op = OP_CAST
		code.value = DATA_INT
		emit(code)
	case TOKEN_DTYPE_PTR:
		code.op = OP_CAST
		code.value = DATA_PTR
		emit(code)

	// Definition
	case TOKEN_CONST:
		registerConstant(token)

	case TOKEN_BRACKET_OPEN:
		// TODO: this will need to handle a lot of errors. Check addBind()
		for match(TOKEN_WORD) {
			t := parser.previous
			bName := t.value.(string)
			val := Bound{name: bName, id: len(frontend.current.bindings)}
			bind(Let{
				btype: BIND,
				name: bName,
				token: t,
				value: val,
			})
			frontend.current.bindings = append(frontend.current.bindings, val)
		}
		consume(TOKEN_BRACKET_CLOSE, "TODO: forgot to close bracket error")
		emit(Code{op: OP_BIND, loc: token.loc, value: len(frontend.current.bindings)})

	// Intrinsics
	case TOKEN_ARGC:
		code.op = OP_ARGC
		emit(code)
	case TOKEN_ARGV:
		code.op = OP_ARGV
		emit(code)
	case TOKEN_ASM:
		addAssembly(token)
	case TOKEN_BANG_EQUAL:
		code.op = OP_NOT_EQUAL
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
	case TOKEN_LEAVE:
		emitReturn()
	case TOKEN_LESS:
		code.op = OP_LESS
		emit(code)
	case TOKEN_LESS_EQUAL:
		code.op = OP_LESS_EQUAL
		emit(code)
	case TOKEN_LET, TOKEN_LETSTAR:
		count := 0
		var newBinds []string
		for match(TOKEN_WORD) {
			w := parser.previous.value.(string)
			count++
			newBinds = append(newBinds, w)
		}
		consume(TOKEN_IN, "TODO: Missing IN keyowrd")
		frontend.current.scope.count = append([]int{count}, frontend.current.scope.count...)
		frontend.current.scope.binds = append(newBinds, frontend.current.scope.binds...)
		code.op = OP_LET_BIND
		code.value = count
		emit(code)
	case TOKEN_DONE:
		unbindAmount := frontend.current.scope.count[0]
		frontend.current.scope.count = frontend.current.scope.count[1:]
		frontend.current.scope.binds = frontend.current.scope.binds[unbindAmount-1:]
		code.op = OP_LET_UNBIND
		code.value = unbindAmount
		emit(code)
	case TOKEN_LOAD8:
		code.op = OP_LOAD8
		emit(code)
	case TOKEN_LOAD16:
		code.op = OP_LOAD16
		emit(code)
	case TOKEN_LOAD32:
		code.op = OP_LOAD32
		emit(code)
	case TOKEN_LOAD64:
		code.op = OP_LOAD64
		emit(code)
	case TOKEN_MINUS:
		code.op = OP_SUBSTRACT
		emit(code)
	case TOKEN_PERCENT:
		code.op = OP_MODULO
		emit(code)
	case TOKEN_PLUS:
		code.op = OP_ADD
		emit(code)
	case TOKEN_SLASH:
		code.op = OP_DIVIDE
		emit(code)
	case TOKEN_STAR:
		code.op = OP_MULTIPLY
		emit(code)
	case TOKEN_STORE8:
		code.op = OP_STORE8
		emit(code)
	case TOKEN_STORE16:
		code.op = OP_STORE16
		emit(code)
	case TOKEN_STORE32:
		code.op = OP_STORE32
		emit(code)
	case TOKEN_STORE64:
		code.op = OP_STORE64
		emit(code)
	case TOKEN_TAKE:
		code.op = OP_TAKE
		emit(code)
	case TOKEN_THIS:
		loc := code.loc
		code.op = OP_PUSH_STR
		code.value = fmt.Sprintf("%s:%d:%d", loc.f, loc.l, loc.c)
		emit(code)

	// Special
	case TOKEN_WORD:
		expandWord(token)
	case TOKEN_UNTIL:
		// Getting the condition from the last IP
		var condition ScopeStartCondition
		lastIPCode := frontend.current.code[len(frontend.current.code)-1]
		frontend.current.code = remove(frontend.current.code, len(frontend.current.code)-1)

		switch lastIPCode.op {
		case OP_NOT_EQUAL		: condition = LC_NOT_EQUAL
		case OP_EQUAL			: condition = LC_EQUAL
		case OP_GREATER			: condition = LC_GREATER
		case OP_GREATER_EQUAL	: condition = LC_GREATER_EQUAL
		case OP_LESS			: condition = LC_LESS
		case OP_LESS_EQUAL		: condition = LC_LESS_EQUAL
		default:
			errorAt(&token, "TODO: ERROR MESSAGE NOT ALLOWED COMPARISON")
			ExitWithError(CodeParseError)
		}

		currentScope := startScope(Scope{
			typ: SCOPE_LOOP,
			startCondition: condition,
			startToken: token,
		})

		loopIndexByte := 72
		loopScopeDepth := getCountForScopeType(SCOPE_LOOP)
		loopIndexByte += loopScopeDepth
		loopIndexLetter := string(byte(loopIndexByte))
		limitName := loopIndexLetter + "limit"


		limitValue := Bound{name: limitName, id: len(frontend.current.bindings)}
		bind(Let{btype: BIND, name: limitName, token: token, value: limitValue})
		frontend.current.bindings = append(frontend.current.bindings, limitValue)

		indexValue := Bound{name: loopIndexLetter, id: len(frontend.current.bindings)}
		bind(Let{btype: BIND, name: loopIndexLetter, token: token, value: indexValue})
		frontend.current.bindings = append(frontend.current.bindings, indexValue)

		emit(Code{op: OP_BIND, loc: token.loc, value: len(frontend.current.bindings)})
		emit(Code{op: OP_PUSH_BOUND, loc: token.loc, value: limitValue})
		emit(Code{op: OP_PUSH_BOUND, loc: token.loc, value: indexValue})

		currentScope.startIP = len(frontend.current.code)
		currentScope.value = LoopScopeValue{
			bindIndexId: indexValue.id,
			bindLimitId: limitValue.id,
		}

		*sLevel++
		frontend.scopeOld[*sLevel].loopCondition = condition
		frontend.scopeOld[*sLevel].typ = SCOPE_LOOP
		frontend.scopeOld[*sLevel].startIP = len(frontend.current.code)

		code.op = OP_LOOP_START
		emit(code)
	case TOKEN_LOOP, TOKEN_LLOOP, TOKEN_NLOOP, TOKEN_PLUSLOOP:
		currentScope := getCurrentScope()

		if currentScope.typ != SCOPE_LOOP {
			// TODO: Improve error message, showing the starting and closing statements
			errorAt(&currentScope.startToken, "TODO: ERROR MESSAGE")
			errorAt(&token, "TODO: ERROR MESSAGE")
			ExitWithError(CodeParseError)
		}

		loopScopeValue := currentScope.value.(LoopScopeValue)

		sValue := Loop{
			bindIndexId: loopScopeValue.bindIndexId,
			bindLimitId: loopScopeValue.bindLimitId,
			condition: currentScope.startCondition,
			gotoIP: len(frontend.current.code),
			level: frontend.scope.currentLevel,
			typ: token.typ,
		}
		eValue := Loop{
			bindIndexId: loopScopeValue.bindIndexId,
			bindLimitId: loopScopeValue.bindLimitId,
			condition: currentScope.startCondition,
			gotoIP: currentScope.startIP,
			level: frontend.scope.currentLevel,
			typ: token.typ,
		}

		frontend.current.code[currentScope.startIP].value = sValue
		code.op = OP_LOOP_END
		code.value = eValue
		emit(code)
		endScope()
		*sLevel--
	case TOKEN_IF:
		*sLevel++
		frontend.scopeOld[*sLevel].tt = token.typ
	case TOKEN_ELSE:
		if *sLevel > 0 {
			prevThen := frontend.scopeOld[*sLevel].thenIP
			frontend.scopeOld[*sLevel].thenIP = len(frontend.current.code)
			code.op = OP_JUMP
			emit(code)
			frontend.current.code[prevThen].value = len(frontend.current.code)
		} else {
			errorAt(&token, MsgParseElseOrphanTokenFound)
		}
	case TOKEN_FOR:
		*sLevel++
		frontend.scopeOld[*sLevel].tt = token.typ
		frontend.scopeOld[*sLevel].loopIP = len(frontend.current.code)
	case TOKEN_PAREN_OPEN:
		frontend.scopeOld[*sLevel].thenIP = len(frontend.current.code)
		code.op = OP_JUMP_IF_FALSE
		emit(code)
	case TOKEN_PAREN_CLOSE:
		cScope := frontend.scopeOld[*sLevel]

		switch cScope.tt {
		case TOKEN_IF:
			code.op = OP_END_IF
			emit(code)
			frontend.current.code[cScope.thenIP].value = len(frontend.current.code)
		case TOKEN_FOR:
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
	}
}

func parseArityInAssembly(token Token, args *Arity) {
	var newArg Argument

	switch token.typ {
	case TOKEN_DTYPE_BOOL:
		newArg.typ = DATA_BOOL
	case TOKEN_DTYPE_CHAR:
		newArg.typ = DATA_CHAR
	case TOKEN_DTYPE_INT:
		newArg.typ = DATA_INT
	case TOKEN_DTYPE_PTR:
		newArg.typ = DATA_PTR
	default:
		msg := fmt.Sprintf(MsgParseTypeUnknown, token.value.(string))
		errorAt(&token, msg)
		ExitWithError(CodeParseError)
	}

	args.types = append(args.types, newArg)
}

func parseArityInFunction(token Token, function *Function, parsingArguments bool) {
	var newArg Argument

	switch token.typ {
	case TOKEN_DTYPE_ANY:
		if !parser.internal {
			errorAt(&token, MsgParseArityArgumentAnyOnlyInternal)
			ExitWithError(CodeParseError)
		}

		newArg.typ = DATA_ANY
	case TOKEN_DTYPE_BOOL:
		newArg.typ = DATA_BOOL
	case TOKEN_DTYPE_CHAR:
		newArg.typ = DATA_CHAR
	case TOKEN_DTYPE_INT:
		newArg.typ = DATA_INT
	case TOKEN_DTYPE_PTR:
		newArg.typ = DATA_PTR
	case TOKEN_DTYPE_PARAPOLY:
		if !parsingArguments {
			errorAt(&token, MsgParseArityReturnParapolyNotAllowed)
			ExitWithError(CodeParseError)
		}

		newArg.typ = DATA_INFER
		newArg.name = token.value.(string)
		function.arguments.parapoly = true
	case TOKEN_WORD:
		w := token.value.(string)

		if parsingArguments {
			msg := fmt.Sprintf(MsgParseTypeUnknown, w)
			errorAt(&token, msg)
			ExitWithError(CodeParseError)
		}

		funcArgs := function.arguments
		argTest := Argument{name: w, typ: DATA_INFER}

		if funcArgs.parapoly && Contains(funcArgs.types, argTest) {
			newArg.typ = DATA_INFER
			newArg.name = w
			function.returns.parapoly = true
		} else {
			msg := fmt.Sprintf(MsgParseArityReturnParapolyNotFound, w)
			errorAt(&token, msg)
			ExitWithError(CodeParseError)
		}
	default:
		msg := fmt.Sprintf(MsgParseTypeUnknown, token.value.(string))
		errorAt(&token, msg)
		ExitWithError(CodeParseError)
	}

	if parsingArguments {
		function.arguments.types = append(function.arguments.types, newArg)
	} else {
		function.returns.types = append(function.returns.types, newArg)
	}
}

func parseFunction(token Token) {
	// Recreate a temporary function entry to match with the already registered
	// functions in TheProgram. That's why this step doesn't have any error checking.
	var testFunc Function

	advance()
	testFunc.name = parser.previous.value.(string)
	advance()

	parsingArguments := true

	for !match(TOKEN_PAREN_CLOSE) {
		advance()
		t := parser.previous

		if t.typ == TOKEN_DASH_DASH_DASH {
			parsingArguments = false
			continue
		}

		parseArityInFunction(t, &testFunc, parsingArguments)
	}

	for index, f := range TheProgram.chunks {
		if !f.parsed && f.name == testFunc.name &&
			reflect.DeepEqual(f.arguments, testFunc.arguments) {
			frontend.current = &TheProgram.chunks[index]
			break
		}
	}

	if frontend.current != nil {
		startScope(Scope{typ: SCOPE_FUNCTION, startToken: token})

		for !match(TOKEN_RET) {
			advance()
			parseToken(parser.previous)
		}

		emitReturn()
		endScope()

		// Marking the function as "parsed", then clearing out the bindings, and
		// removing the pointer to this function, so we can safely check for the next one.
		frontend.current.parsed = true
		frontend.current = nil
	} else {
		// This would be a catastrophic issue. Since we already registered functions,
		// there's no way we don't find a function with the same name that has not been
		// parsed yet. Since we can't recover from this error, we must exit.
		msg := fmt.Sprintf(MsgParseFunctionSignatureNotFound, testFunc.name)
		errorAt(&parser.previous, msg)
		ExitWithError(CodeParseError)
	}
}

/*
 * Compilation: First Pass
 *   This step goes through the files and check for the TOKEN_USING, adding those
 *   files to the compilation queue.
 */
func compilationFirstPass(index int) {
	f := file.files[index]

	startParser(f)

	for !check(TOKEN_EOF) {
		advance()
		token := parser.previous

		if token.typ == TOKEN_USING {
			advance()

			if parser.previous.typ != TOKEN_WORD {
				errorAt(&parser.previous, "TODO: ERROR USING")
				ExitWithError(CodeParseError)
			}

			file.Open(parser.previous.value.(string))
		}
	}
}

/*
 * Compilation: Second Pass
 *   The second step registers the words the program will use.
 */
func compilationSecondPass(index int) {
	f := file.files[index]

	startParser(f)

	for !check(TOKEN_EOF) {
		advance()
		token := parser.previous

		switch token.typ {
		// The second pass will care about the following tokens:
		case TOKEN_CONST: registerConstant(token)
		case TOKEN_VAR: registerVar(token)
		case TOKEN_FN: registerFunction(token)

		// But it needs to do nothing when it sees the followings:
		//   TOKEN_USING: advance over the string, then continue back to the loop.
		case TOKEN_USING:
			advance()
			continue

		// Now, if it matches with something else, then error.
		default:
			ReportErrorAtLocation(MsgParseErrorProgramScope, token.loc)
			ExitWithError(CodeParseError)
		}
	}
}

/*
 * Compilation: Third Pass
 *   The third step goes through each function and compiles the code for each one
 *   of them. Register and make all the OP codes for these functions.
 */
func compilationThirdPass(index int) {
	f := file.files[index]

	startParser(f)

	for !check(TOKEN_EOF) {
		advance()
		token := parser.previous

		if token.typ == TOKEN_FN {
			parseFunction(token)
		}
	}
}

func FrontendRun() {
	// Core standard library
	file.Open("runtime")

	// User entry file
	file.Open(Stanczyk.workspace.entry)

	startScope(Scope{typ: SCOPE_GLOBAL})

	// I'm not using "range" because Go creates a copy of the Array
	// (turning it into a slice), so if I find a new file while
	// going through the compilation, it will not update the `for` statement.
	for index := 0; index < len(file.files); index++ {
		compilationFirstPass(index)
	}

	for index := 0; index < len(file.files); index++ {
		compilationSecondPass(index)
	}

	for index := 0; index < len(file.files); index++ {
		compilationThirdPass(index)
	}

	endScope()

	TheProgram.variables = frontend.variables

	if frontend.error {
		ExitWithError(CodeParseError)
	}
}

func remove(slice []Code, s int) []Code {
    return append(slice[:s], slice[s+1:]...)
}
