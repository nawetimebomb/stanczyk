package main

import "core:fmt"
import "core:log"
import "core:strconv"

Arithmetic_Operation_Kind :: enum {
    divide, modulo, multiply, substract, sum,
}

Comparison_Operation_Kind :: enum {
    equal, greater, greater_equal, less, less_equal, not_equal,
}

Op_Push_Bool        :: struct { value: bool }
Op_Push_Float       :: struct { value: f64 }
Op_Push_Integer     :: struct { value: int }
Op_Push_String      :: struct { value: string }

Op_Arithmetic       :: struct {
    operands: Type_Primitive_Kind, operation: Arithmetic_Operation_Kind,
}
Op_Comparison       :: struct {
    operands: Type_Primitive_Kind, operation: Comparison_Operation_Kind,
}
Op_Concat_String    :: struct {}
Op_Drop             :: struct {}
Op_Dup              :: struct {}
Op_Print            :: struct { kind: Type_Variant, newline: bool }
Op_Swap             :: struct {}

Operation_Kind :: union {
    Op_Push_Bool,
    Op_Push_Float,
    Op_Push_Integer,
    Op_Push_String,

    Op_Arithmetic,
    Op_Comparison,
    Op_Concat_String,
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

    sim_stack:  [dynamic]Type_Variant,
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

parse_arithmetic_operation :: proc(tk: Token_Kind) -> Arithmetic_Operation_Kind {
    #partial switch tk {
        case .Minus:      return .substract
        case .Percentage: return .modulo
        case .Plus:       return .sum
        case .Slash:      return .divide
        case .Star:       return .multiply
    }

    assert(false)
    return .sum
}

parse_comparison_operation :: proc(tk: Token_Kind) -> Comparison_Operation_Kind {
    #partial switch tk {
        case .Bang_Equal:    return .not_equal
        case .Equal:         return .equal
        case .Greater:       return .greater
        case .Greater_Equal: return .greater_equal
        case .Less:          return .less
        case .Less_Equal:    return .less_equal
    }

    assert(false)
    return .equal
}

@(private="file")
parse_token :: proc(p: ^Parser) {
    t := p.previous

    if !is_parsing_procedure(p) {
        // TODO: Error
        unimplemented()
    }

    switch t.kind {
    case .Invalid:
        // The tokenizer couldn't figure out what this token meant, so if there's a
        // bug, it's in that part of the code.
        log.errorf(ERROR_INVALID_TOKEN, t)
    case .Comment:
        // Note: Skipping the comment tokens for now, but might be interesting to
        // keep them around in case we're able to use them.
    case .EOF:
        // This marks the end of the loop, should always be at the end of the file.
    case .Colon_Colon:
        // This has to be an error as .Colon_Colon should be parsed as part of an
        // identifier, like a constant or a procedure. If it got here it's because
        // there's a bug in the compiler where it cannot be parsed correctly.
        log.errorf(ERROR_INVALID_TOKEN, t)
    case .Dot_Exit:
        // This is only used in REPL mode. If found in source, it throws an error.
        log.errorf(ERROR_INVALID_TOKEN, t)

    case .Identifier:     unimplemented()

    case .Integer:
        append(&p.sim_stack, Type_Primitive{ kind = .int })
        emit(p, Operation{ kind = Op_Push_Integer{ value = strconv.atoi(t.source) }})
    case .Float:
        append(&p.sim_stack, Type_Primitive{ kind = .float })
        emit(p, Operation{ kind = Op_Push_Float{ value = strconv.atof(t.source) }})
    case .Character:
        unimplemented()
    case .String:
        append(&p.sim_stack, Type_Primitive{ kind = .string })
        // Note: Removing the `"` chars that come from the tokenizer
        str_value := t.source[1:len(t.source) - 1]
        emit(p, Operation{ kind = Op_Push_String{ value = str_value }})

    case .Minus, .Percentage, .Plus, .Slash, .Star:
        b := pop(&p.sim_stack)
        a := pop(&p.sim_stack)

        switch {
        case type_is_int(a) && type_is_int(b):
            emit(p, Operation{ kind = Op_Arithmetic{ operands = .int, operation = parse_arithmetic_operation(t.kind) }})
            append(&p.sim_stack, Type_Primitive{ kind = .int })
        case type_is_float(a) && type_is_float(b):
            assert(false)
        case t.kind == .Plus && type_is_string(a) && type_is_string(b):
            emit(p, Operation{ kind = Op_Concat_String{} })
            append(&p.sim_stack, Type_Primitive{ kind = .string })
        case :
            unimplemented()
        }
    case .Paren_Left:
        unimplemented()
    case .Paren_Right:
        unimplemented()
    case .Semicolon:
        assert(false)

    case .Bang:
        unimplemented()
    case .Bang_Equal, .Equal, .Greater, .Greater_Equal, .Less, .Less_Equal:
        b := pop(&p.sim_stack)
        a := pop(&p.sim_stack)

        switch {
        case type_is_int(a) && type_is_int(b):
            emit(p, Operation{ kind = Op_Comparison{ operands = .int, operation = parse_comparison_operation(t.kind) }})
            append(&p.sim_stack, Type_Primitive{ kind = .bool })
        case type_is_float(a) && type_is_float(b):
            emit(p, Operation{ kind = Op_Comparison{ operands = .float, operation = parse_comparison_operation(t.kind) }})
            append(&p.sim_stack, Type_Primitive{ kind = .bool })
        case (t.kind == .Bang_Equal || t.kind == .Equal) && type_is_string(a) && type_is_string(b):
            emit(p, Operation{ kind = Op_Comparison{ operands = .string, operation = parse_comparison_operation(t.kind) }})
            append(&p.sim_stack, Type_Primitive{ kind = .bool })
        }
    case .Keyword_Dup:
        v := pop(&p.sim_stack)
        append(&p.sim_stack, v, v)
        emit(p, Operation { kind = Op_Dup{} })
    case .Keyword_False, .Keyword_True:
        append(&p.sim_stack, Type_Primitive{ kind = .bool })
        emit(p, Operation{ kind = Op_Push_Bool{ value = t.kind == .Keyword_True }})
    case .Keyword_Enum:
        unimplemented()
    case .Keyword_Print, .Keyword_Println:
        type_variant := pop(&p.sim_stack)
        emit(p, Operation{ kind = Op_Print{ kind = type_variant, newline = t.kind == .Keyword_Println }})
    case .Keyword_Struct:
        unimplemented()
    case .Keyword_Swap:
        b := pop(&p.sim_stack)
        a := pop(&p.sim_stack)
        append(&p.sim_stack, b, a)
        emit(p, Operation{ kind = Op_Swap{} })
    case .Keyword_Typeof:
        type_variant := pop(&p.sim_stack)
        emit(p, Operation{ kind = Op_Drop{} })
        emit(p, Operation{ kind = Op_Push_String{ value = type_to_string(Type{ variant = type_variant })}})
        append(&p.sim_stack, Type_Primitive{ kind = .string })
    case .Keyword_Using:
        unimplemented()
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
            t := p.previous

            #partial switch t.kind {
                case .Identifier: {
                    if consume(p, .Colon_Colon) {
                        switch {
                        case check(p, .Paren_Left):     register_procedure(p, t)
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
            t := p.previous

            #partial switch t.kind {
                case .Identifier: {
                    consume(p, .Colon_Colon)

                    if check(p, .Paren_Left) {
                        start_parsing_procedure(p, t)

                        for !is_eof(p) && !consume(p, .Semicolon) {
                            advance(p)
                            parse_token(p)
                        }

                        end_parsing_procedure(p)
                    }
                }
            }
        }

        free_all(context.temp_allocator)
    }
}
