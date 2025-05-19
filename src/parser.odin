package main

import "core:fmt"
import "core:log"
import "core:strconv"

Binary_Operation :: enum {
    and, concat, divide, equal, greater,
    greater_equal, less, less_equal,
    modulo, multiply, not_equal,
    or, substract, sum,
}

Op_Push_Bool        :: struct { value: bool }
Op_Push_Float       :: struct { value: f64 }
Op_Push_Integer     :: struct { value: int }
Op_Push_String      :: struct { value: string }

Op_Binary           :: struct { operands: Type, operation: Binary_Operation }
Op_Cast             :: struct { from: Type, to: Type }
Op_Drop             :: struct {}
Op_Dup              :: struct {}
Op_Print            :: struct { operand: Type, newline: bool }
Op_Swap             :: struct {}

Operation_Kind :: union {
    Op_Push_Bool,
    Op_Push_Float,
    Op_Push_Integer,
    Op_Push_String,

    Op_Binary,
    Op_Cast,
    Op_Drop,
    Op_Dup,
    Op_Print,
    Op_Swap,
}

Operation :: struct {
    kind: Operation_Kind,
    loc:  Location,
}

@(private="file")
Scope :: struct {
    kind: enum { Global, Procedure, Statement, },
    parent: ^Procedure,
}

@(private="file")
Parser :: struct {
    tokens:     []Token,
    offset:     int,
    max_offset: int,
    previous:   ^Token,
    current:    ^Token,

    scopes:     [dynamic]Scope,
    chunk:      ^Procedure,
}

@(private="file")
sim_stack: [dynamic]Type

@(private="file")
sim_pop :: proc() -> (a: Type) {
    return pop(&sim_stack)
}

@(private="file")
sim_pop2 :: proc() -> (a, b: Type) {
    return pop(&sim_stack), pop(&sim_stack)
}

@(private="file")
sim_push :: proc(t: Type) {
    append(&sim_stack, t)
}

@(private="file")
at_least :: proc(amount: int, tests: []type_test_proc = {}, loc := #caller_location) -> (res: bool) {
    res = len(sim_stack) >= amount

    if len(tests) > 0 {
        for test_proc in tests {
            for x in 0..<amount {
                item := sim_stack[len(sim_stack) - 1 - x]
                res = test_proc(item)
                if !res { break }
            }

            if res { break }
        }
    }

    // TODO: Add error
    assert(res, "Can't be false, stack should be valid all the time {}", loc)
    return
}

@(private="file")
start_parser :: proc(t: []Token) -> (p: Parser) {
    p.tokens = t
    p.offset = 0
    p.max_offset = len(t)
    p.previous = &t[0]
    p.current = &t[0]
    return
}

@(private="file")
advance :: proc(p: ^Parser) {
    p.offset += 1
    if is_eof(p) { return }
    p.previous = p.current
    p.current = &p.tokens[p.offset]
}

@(private="file")
emit :: proc(p: ^Parser, op: Operation) {
    new_op := op
    new_op.loc = get_location(p.previous)
    append(&p.chunk.ops, new_op)
}

@(private="file")
is_eof :: proc(p: ^Parser) -> (result: bool) {
    return p.current.kind == .EOF || p.offset >= p.max_offset
}

@(private="file")
consume :: proc(p: ^Parser, tk: Token_Kind) -> (result: bool) {
    if check(p, tk) {
        advance(p)
        return true
    }

    return false
}

@(private="file")
check :: proc(p: ^Parser, tk: Token_Kind) -> (result: bool) {
    return p.current.kind == tk
}

@(private="file")
is_parsing_procedure :: proc(p: ^Parser) -> (result: bool) {
    return p.chunk != nil
}

@(private="file")
get_location :: proc(t: ^Token) -> Location {
    return Location{ file = t.file, offset = t.start }
}

@(private="file")
start_parsing_procedure :: proc(p: ^Parser, t: ^Token) {
    name := t.source

    // Register arity and results to support polymorphism
    for !is_eof(p) && !consume(p, .Paren_Right) { advance(p) }

    for &c in program.procs {
        if c.name == name {
            p.chunk = &c
            break
        }
    }
}

@(private="file")
end_parsing_procedure :: proc(p: ^Parser) {
    p.chunk = nil
}

@(private="file")
parse_token :: proc(p: ^Parser) {
    token := p.previous

    if !is_parsing_procedure(p) {
        // TODO: Error
        unimplemented()
    }

    switch token.kind {
    case .Invalid:
        // The tokenizer couldn't figure out what this token meant, so if there's a
        // bug, it's in that part of the code.
        log.errorf(ERROR_INVALID_TOKEN, token)
    case .Comment:
        // Note: Skipping the comment tokens for now, but might be interesting to
        // keep them around in case we're able to use them.
    case .EOF:
        // This marks the end of the loop, should always be at the end of the file.
    case .Colon_Colon:
        // This has to be an error as .Colon_Colon should be parsed as part of an
        // identifier, like a constant or a procedure. If it got here it's because
        // there's a bug in the compiler where it cannot be parsed correctly.
        log.errorf(ERROR_INVALID_TOKEN, token)
    case .Dot_Exit:
        // This is only used in REPL mode. If found in source, it throws an error.
        log.errorf(ERROR_INVALID_TOKEN, token)

    case .Identifier:     unimplemented()

    case .Bool_False, .Bool_True:
        sim_push(type_create_primitive(.bool))
        emit(p, Operation{ kind = Op_Push_Bool{ value = token.kind == .Bool_True }})
    case .Integer:
        sim_push(type_create_primitive(.int))
        emit(p, Operation{ kind = Op_Push_Integer{ value = strconv.atoi(token.source) }})
    case .Float:
        sim_push(type_create_primitive(.float))
        emit(p, Operation{ kind = Op_Push_Float{ value = strconv.atof(token.source) }})
    case .Character:
        unimplemented()
    case .String:
        sim_push(type_create_primitive(.string))
        // Note: Removing the `"` chars that come from the tokenizer
        str_value := token.source[1:len(token.source) - 1]
        emit(p, Operation{ kind = Op_Push_String{ value = str_value }})

    case .Bang:
        unimplemented()
    case .Bang_Equal:
        at_least(2, {type_is_int, type_is_float, type_is_string})
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .not_equal }})
        sim_push(type_create_primitive(.bool))
    case .Equal:
        at_least(2, {type_is_int, type_is_float, type_is_string})
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .equal }})
        sim_push(type_create_primitive(.bool))
    case .Greater:
        at_least(2, {type_is_int, type_is_float})
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .greater }})
        sim_push(type_create_primitive(.bool))
    case .Greater_Equal:
        at_least(2, {type_is_int, type_is_float})
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .greater_equal }})
        sim_push(type_create_primitive(.bool))
    case .Less:
        at_least(2, {type_is_int, type_is_float})
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .less }})
        sim_push(type_create_primitive(.bool))
    case .Less_Equal:
        at_least(2, {type_is_int, type_is_float})
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .less_equal }})
        sim_push(type_create_primitive(.bool))
    case .Minus:
        at_least(2, {type_is_int, type_is_float})
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .substract }})
        sim_push(t)
    case .Percentage:
        at_least(2, {type_is_int})
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .modulo }})
        sim_push(t)
    case .Plus:
        at_least(2, {type_is_int, type_is_float, type_is_string})
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = type_is_string(t) ? .concat : .sum }})
        sim_push(t)
    case .Slash:
        at_least(2, {type_is_int, type_is_float})
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .divide }})
        sim_push(t)
    case .Star:
        at_least(2, {type_is_int, type_is_float})
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .multiply }})
        sim_push(t)

    case .Dash_Dash_Dash, .Paren_Left, .Paren_Right, .Semicolon:
        assert(false, "Can't parse within a procedure")

    case .Keyword_And:
        at_least(2, {type_is_bool})
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .and }})
        sim_push(t)
    case .Keyword_Dup:
        at_least(1)
        t := sim_pop()
        emit(p, Operation{ kind = Op_Dup{} })
        sim_push(t)
        sim_push(t)
    case .Keyword_Or:
        at_least(2, {type_is_bool})
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .or }})
        sim_push(t)
    case .Keyword_Enum:
        unimplemented()
    case .Keyword_Print, .Keyword_Println:
        at_least(1)
        t := sim_pop()
        emit(p, Operation{ kind = Op_Print{ operand = t, newline = token.kind == .Keyword_Println }})
    case .Keyword_Struct:
        unimplemented()
    case .Keyword_Swap:
        at_least(2)
        b, a := sim_pop2()
        emit(p, Operation{ kind = Op_Swap{} })
        sim_push(b)
        sim_push(a)
    case .Keyword_Type:
        assert(false, "Can't parse 'type' within procedure")
    case .Keyword_Typeof:
        at_least(1)
        t := sim_pop()
        emit(p, Operation{ kind = Op_Drop{} })
        emit(p, Operation{ kind = Op_Push_String{ value = type_to_string(t) }})
        sim_push(type_create_primitive(.string))
    case .Keyword_Using:
        unimplemented()

    case .Type_Bool:
        at_least(1)
        from := sim_pop()
        to := type_create_primitive(.bool)
        emit(p, Operation{ kind = Op_Cast{ from = from, to = to }})
        sim_push(to)
    case .Type_Float:
        at_least(1, {type_is_int})
        from := sim_pop()
        to := type_create_primitive(.float)
        emit(p, Operation{ kind = Op_Cast{ from = from, to = to }})
        sim_push(to)
    case .Type_Int:
        at_least(1, {type_is_float})
        from := sim_pop()
        to := type_create_primitive(.int)
        emit(p, Operation{ kind = Op_Cast{ from = from, to = to }})
        sim_push(to)
    case .Type_Ptr:
        at_least(1, {type_is_primitive})
        from := sim_pop()
        to := type_create_pointer(type_get_primitive(from))
        emit(p, Operation{ kind = Op_Cast{ from = from, to = to }})
        sim_push(to)
    case .Type_String:
        at_least(1, {type_is_bool, type_is_int, type_is_float})
        from := sim_pop()
        to := type_create_primitive(.string)
        emit(p, Operation{ kind = Op_Cast{ from = from, to = to }})
        sim_push(to)
    }
}

@(private="file")
register_procedure :: proc(p: ^Parser, t: ^Token) {
    new_proc: Procedure

    new_proc.called = t.source == "main"
    new_proc.ip = len(program.procs)
    new_proc.loc = get_location(t)
    new_proc.name = t.source
    new_proc.token = t^

    append(&program.procs, new_proc)

    consume(p, .Paren_Left)

    // Parse the arity and result
    if !check(p, .Paren_Right) {

    }

    consume(p, .Paren_Right)
    for !is_eof(p) && !check(p, .Semicolon) { advance(p) }
    consume(p, .Semicolon)
}

parse_files :: proc() {
    // Note: If a global error has been found, like code that shouldn't be
    // in the global scope, an error report should be posted and the second
    // compilation step shouldn't run.

    // First pass in compilation makes sure all files are loaded correctly.
    for filepath, source in source_files {
        parser := start_parser(tokenize(source, filepath))
        p := &parser

        for !is_eof(p) {
            advance(p)
            token := p.previous

            #partial switch token.kind {
                case .Identifier: {
                    if consume(p, .Colon_Colon) {
                        switch {
                        case check(p, .Paren_Left):     register_procedure(p, token)
                        case check(p, .Keyword_Enum):   unimplemented()
                        case check(p, .Keyword_Struct): unimplemented()
                        case :                          unimplemented()
                        }
                    } else {
                        unimplemented()
                    }
                }
                case .Keyword_Using: //parse_using(p)
            }
        }

        free_all(context.temp_allocator)
    }

    for filepath, source in source_files {
        parser := start_parser(tokenize(source, filepath))
        p := &parser

        for !is_eof(p) {
            advance(p)
            token := p.previous

            #partial switch token.kind {
                case .Identifier: {
                    consume(p, .Colon_Colon)

                    if check(p, .Paren_Left) {
                        start_parsing_procedure(p, token)

                        for !is_eof(p) && !consume(p, .Semicolon) {
                            advance(p)
                            parse_token(p)
                        }

                        end_parsing_procedure(p)
                    }
                }
            }
        }

        if len(sim_stack) > 0 {
            // TODO: Add error
            assert(false, "Stack should be empty at execution's end")
        }

        free_all(context.temp_allocator)
    }
}
