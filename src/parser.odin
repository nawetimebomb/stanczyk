package main

import "core:fmt"
import "core:log"
import "core:reflect"
import "core:strconv"

Unary_Operation :: enum u8 {
    minus_minus, plus_plus,
}

Binary_Operation :: enum u8 {
    and, or,
    plus, divide, minus, multiply, modulo,
    ge, gt, le, lt, eq, ne,
}

Op_Push_Bool        :: struct { value: bool }
Op_Push_Float       :: struct { value: f64 }
Op_Push_Integer     :: struct { value: int }
Op_Push_String      :: struct { value: string }

Op_Binary           :: struct { operands: Type, operation: Binary_Operation }
Op_Call_Proc        :: struct { name: string, ip: int }
Op_Cast             :: struct { from: Type, to: Type }
Op_Drop             :: struct {}
Op_Dup              :: struct {}
Op_Print            :: struct { operand: Type, newline: bool }
Op_Swap             :: struct {}
Op_Unary            :: struct { operand: Type, operation: Unary_Operation }

Operation_Kind :: union {
    Op_Push_Bool,
    Op_Push_Float,
    Op_Push_Integer,
    Op_Push_String,

    Op_Binary,
    Op_Call_Proc,
    Op_Cast,
    Op_Drop,
    Op_Dup,
    Op_Print,
    Op_Swap,
    Op_Unary,
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
            for type in c.arguments.types { sim_push(type) }
            break
        }
    }
}

@(private="file")
end_parsing_procedure :: proc(p: ^Parser) {
    fmt.assertf(p.chunk.results.amount == len(sim_stack), "stack mismatch, expected {}, got {}", p.chunk.results.amount, len(sim_stack))
    clear(&sim_stack)
    p.chunk = nil
}

@(private="file")
parse_token :: proc(p: ^Parser) {
    token := p.previous

    // TODO: add proper error
    assert(is_parsing_procedure(p))

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

    case .Identifier:
        // Note: Identifiers can be variables, bindings, constants or even other procedures, but they
        // also can be unknown. The order I want to have is to search for bindings first, variables second,
        // constants third and lastly, a procedure.
        parsed := false
        ok: bool
        ip: int
        name := token.source

        // if ip, ok = is_identifier_binding(name); ok { return }
        //if ip, ok = is_identifier_variable(name); ok { return }
        //if ip, ok = is_identifier_constant(name); ok { return }
        for procedure in program.procs {
            if procedure.name == token.source {
                // Maybe found, make sure it matches the arity
                if sim_match(procedure.arguments.amount, procedure.arguments.types[:]) {
                    for x in 0..<procedure.arguments.amount { sim_pop() }
                    for type in procedure.results.types { sim_push(type) }
                    emit(p, Operation{ kind = Op_Call_Proc{ name = procedure.name, ip = procedure.ip }})
                    return
                }
            }
        }

    case .Bool_False, .Bool_True:
        sim_push(type_create_primitive(.bool))
        emit(p, Operation{ kind = Op_Push_Bool{ value = token.kind == .Bool_True }})
    case .Integer:
        sim_push(type_create_primitive(is_64bit() ? .s64 : .s32))
        emit(p, Operation{ kind = Op_Push_Integer{ value = strconv.atoi(token.source) }})
    case .Float:
        sim_push(type_create_primitive(is_64bit() ? .f64 : .f32))
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
        sim_expect(p.chunk, sim_at_least(2), sim_one_of_primitive(..TYPE_ALL_PRIMITIVE))
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .ne }})
        sim_push(type_create_primitive(.bool))
    case .Equal:
        sim_expect(p.chunk, sim_at_least(2), sim_one_of_primitive(..TYPE_ALL_PRIMITIVE))
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .eq }})
        sim_push(type_create_primitive(.bool))
    case .Greater:
        sim_expect(p.chunk, sim_at_least(2), sim_one_of_primitive(..TYPE_ALL_NUMBER))
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .gt }})
        sim_push(type_create_primitive(.bool))
    case .Greater_Equal:
        sim_expect(p.chunk, sim_at_least(2), sim_one_of_primitive(..TYPE_ALL_NUMBER))
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .ge }})
        sim_push(type_create_primitive(.bool))
    case .Less:
        sim_expect(p.chunk, sim_at_least(2), sim_one_of_primitive(..TYPE_ALL_NUMBER))
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .lt }})
        sim_push(type_create_primitive(.bool))
    case .Less_Equal:
        sim_expect(p.chunk, sim_at_least(2), sim_one_of_primitive(..TYPE_ALL_NUMBER))
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .le }})
        sim_push(type_create_primitive(.bool))
    case .Minus:
        sim_expect(p.chunk, sim_at_least(2), sim_one_of_primitive(..TYPE_ALL_NUMBER))
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .minus }})
        sim_push(t)
    case .Minus_Minus:
        sim_expect(p.chunk, sim_at_least(1), sim_one_of_primitive(..TYPE_ALL_NUMBER))
        t := sim_peek()
        emit(p, Operation{ kind = Op_Unary{ operand = t, operation = .minus_minus }})
    case .Percentage:
        sim_expect(p.chunk, sim_at_least(2), sim_one_of_primitive(..TYPE_ALL_REAL_NUMBER))
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .modulo }})
        sim_push(t)
    case .Plus:
        sim_expect(p.chunk, sim_at_least(2), sim_one_of_primitive(..TYPE_ALL_PRIMITIVE), !sim_match_type(type_create_primitive(.bool)))
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .plus }})
        sim_push(t)
    case .Plus_Plus:
        sim_expect(p.chunk, sim_at_least(1), sim_one_of_primitive(..TYPE_ALL_NUMBER))
        t := sim_peek()
        emit(p, Operation{ kind = Op_Unary{ operand = t, operation = .plus_plus }})
    case .Slash:
        sim_expect(p.chunk, sim_at_least_same_type(2), sim_one_of_primitive(..TYPE_ALL_NUMBER))
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .divide }})
        sim_push(t)
    case .Star:
        sim_expect(p.chunk, sim_at_least_same_type(2), sim_one_of_primitive(..TYPE_ALL_NUMBER))
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .multiply }})
        sim_push(t)

    case .Dash_Dash_Dash, .Paren_Left, .Paren_Right, .Semicolon:
        assert(false, "Can't parse within a procedure")

    case .Keyword_And:
        sim_expect(p.chunk, sim_at_least(2), sim_one_of_primitive(.bool))
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .and }})
        sim_push(t)
    case .Keyword_Dup:
        sim_expect(p.chunk, sim_at_least(1))
        t := sim_pop()
        emit(p, Operation{ kind = Op_Dup{} })
        sim_push(t)
        sim_push(t)
    case .Keyword_Or:
        sim_expect(p.chunk, sim_at_least(2), sim_one_of_primitive(.bool))
        t, _ := sim_pop2()
        emit(p, Operation{ kind = Op_Binary{ operands = t, operation = .or }})
        sim_push(t)
    case .Keyword_Enum:
        unimplemented()
    case .Keyword_Print, .Keyword_Println:
        sim_expect(p.chunk, sim_at_least(1))
        t := sim_pop()
        emit(p, Operation{ kind = Op_Print{ operand = t, newline = token.kind == .Keyword_Println }})
    case .Keyword_Struct:
        unimplemented()
    case .Keyword_Swap:
        sim_expect(p.chunk, sim_at_least(2))
        b, a := sim_pop2()
        emit(p, Operation{ kind = Op_Swap{} })
        sim_push(b)
        sim_push(a)
    case .Keyword_Type:
        assert(false, "Can't parse 'type' within procedure")
    case .Keyword_Typeof:
        // TODO: this is currently pushing a string with the name of the last item
        // in the stack, but technically, it should be able to push the
        // type information
        sim_expect(p.chunk, sim_at_least(1))
        t := sim_pop()
        emit(p, Operation{ kind = Op_Drop{} })
        emit(p, Operation{ kind = Op_Push_String{ value = type_to_cname(t) }})
        sim_push(type_create_primitive(.string))
    case .Keyword_Using:
        unimplemented()

    case .Type_Bool:
        sim_expect(p.chunk, sim_at_least(1), sim_one_of_primitive(..TYPE_ALL_PRIMITIVE))
        from := sim_pop()
        to := type_create_primitive(.bool)
        emit(p, Operation{ kind = Op_Cast{ from = from, to = to }})
        sim_push(to)
    case .Type_Float:
        sim_expect(p.chunk, sim_at_least(1), sim_one_of_primitive(..TYPE_ALL_NUMBER))
        from := sim_pop()
        to := type_create_primitive(is_64bit() ? .f64 : .f32)
        emit(p, Operation{ kind = Op_Cast{ from = from, to = to }})
        sim_push(to)
    case .Type_F64, .Type_F32:
        sim_expect(p.chunk, sim_at_least(1), sim_one_of_primitive(..TYPE_ALL_NUMBER))
        from := sim_pop()
        to := type_create_primitive(token.kind == .Type_F64 ? .f64 : .f32)
        emit(p, Operation{ kind = Op_Cast{ from = from, to = to }})
        sim_push(to)
    case .Type_Int:
        sim_expect(p.chunk, sim_at_least(1), sim_one_of_primitive(..TYPE_ALL_NUMBER))
        from := sim_pop()
        to := type_create_primitive(is_64bit() ? .s64 : .s32)
        emit(p, Operation{ kind = Op_Cast{ from = from, to = to }})
        sim_push(to)
    case .Type_Ptr:
        sim_expect(p.chunk, sim_at_least(1), sim_one_of_primitive(..TYPE_ALL_PRIMITIVE))
        from := sim_pop()
        to := type_create_pointer(type_get_primitive(from))
        emit(p, Operation{ kind = Op_Cast{ from = from, to = to }})
        sim_push(to)
    case .Type_S64, .Type_S32, .Type_S16, .Type_S8:
        sim_expect(p.chunk, sim_at_least(1), sim_one_of_primitive(..TYPE_ALL_NUMBER))
        type, ok := reflect.enum_from_name(Primitive, token.source)
        assert(ok)
        from := sim_pop()
        to := type_create_primitive(type)
        emit(p, Operation{ kind = Op_Cast{ from = from, to = to }})
        sim_push(to)
    case .Type_String:
        sim_expect(p.chunk, sim_at_least(1), sim_one_of_primitive(..TYPE_ALL_PRIMITIVE), !sim_match_type(type_create_primitive(.string)))
        from := sim_pop()
        to := type_create_primitive(.string)
        emit(p, Operation{ kind = Op_Cast{ from = from, to = to }})
        sim_push(to)
    case .Type_U64, .Type_U32, .Type_U16, .Type_U8:
        sim_expect(p.chunk, sim_at_least(1), sim_one_of_primitive(..TYPE_ALL_NUMBER))
        type, ok := reflect.enum_from_name(Primitive, token.source)
        assert(ok)
        from := sim_pop()
        to := type_create_primitive(type)
        emit(p, Operation{ kind = Op_Cast{ from = from, to = to }})
        sim_push(to)
    case .Type_Uint:
        sim_expect(p.chunk, sim_at_least(1), sim_one_of_primitive(..TYPE_ALL_NUMBER))
        from := sim_pop()
        to := type_create_primitive(is_64bit() ? .u64 : .u32)
        emit(p, Operation{ kind = Op_Cast{ from = from, to = to }})
        sim_push(to)
    }
}

@(private="file")
register_procedure :: proc(p: ^Parser, t: ^Token, loc := #caller_location) {
    new_proc: Procedure

    new_proc.called = t.source == "main"
    new_proc.ip = len(program.procs)
    new_proc.loc = get_location(t)
    new_proc.name = t.source
    new_proc.token = t^

    consume(p, .Paren_Left)

    // Parse the arity and result
    if !check(p, .Paren_Right) {
        parsing_args := true

        for !is_eof(p) && !check(p, .Paren_Right) {
            advance(p)
            token := p.previous

            if token.kind == .Dash_Dash_Dash {
                // Now parsing results
                parsing_args = false
                continue
            }

            arity := parsing_args ? &new_proc.arguments : &new_proc.results
            type: Type

            #partial switch token.kind {
                case .Type_Bool:      type = type_create_primitive(.bool)
                case .Type_F64:       type = type_create_primitive(.f64)
                case .Type_F32:       type = type_create_primitive(.f32)
                case .Type_Float:     type = type_create_primitive(is_64bit() ? .f64 : .f32)
                case .Type_Int:       type = type_create_primitive(is_64bit() ? .s64 : .s32)
                //case .Type_Ptr:       type = type_create_pointer()
                case .Type_S64:       type = type_create_primitive(.s64)
                case .Type_S32:       type = type_create_primitive(.s32)
                case .Type_S16:       type = type_create_primitive(.s16)
                case .Type_S8:        type = type_create_primitive(.s8)
                case .Type_String:    type = type_create_primitive(.string)
                case .Type_U64:       type = type_create_primitive(.u64)
                case .Type_U32:       type = type_create_primitive(.u32)
                case .Type_U16:       type = type_create_primitive(.u16)
                case .Type_U8:        type = type_create_primitive(.u8)
                case .Type_Uint:      type = type_create_primitive(is_64bit() ? .u64 : .u32)
                case : fmt.assertf(false, "Failed at token: {}", token)
            }

            arity.amount += 1
            append(&arity.types, type)
        }
    }

    consume(p, .Paren_Right)
    for !is_eof(p) && !check(p, .Semicolon) { advance(p) }
    consume(p, .Semicolon)

    append(&program.procs, new_proc)
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

        free_all(context.temp_allocator)
    }
}
