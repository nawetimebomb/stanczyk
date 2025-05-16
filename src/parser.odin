package main

import "core:fmt"
import "core:log"

Op_Push_Integer :: struct {
    value: int,
}

Op_Push_String :: struct {
    value: string,
}

Op_Print :: struct {
    newline: bool,
}

Op_Repl_Exit :: struct {}

Operation_Kind :: union {
    Op_Push_Integer,
    Op_Push_String,

    Op_Print,

    Op_Repl_Exit,
}

Operation :: struct {
    kind: Operation_Kind,
    loc:  Location,
}

Scope :: struct {
    kind: enum { Global, Procedure, Statement, },
    parent: ^Procedure,
}

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
            break
        }
    }
}

@(private="file")
end_parsing_procedure :: proc(p: ^Parser) {
    p.chunk = nil
}

@(private="file")
emit_string :: proc(p: ^Parser) {
    t := p.previous

    if !is_parsing_procedure(p) {
        // TODO: Error
        unimplemented()
    }

    emit(p, Operation{ kind = Op_Push_String{ value = t.source } })
}

@(private="file")
emit_print :: proc(p: ^Parser, newline := false) {
    emit(p, Operation{ kind = Op_Print{ newline = newline } })
}

@(private="file")
parse_token :: proc(p: ^Parser) {
    t := p.previous

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

    case .Identifier: unimplemented()

    case .Integer: unimplemented()
    case .Float: unimplemented()
    case .Character: unimplemented()
    case .String: emit_string(p)

    case .Minus: unimplemented()
    case .Paren_Left: unimplemented()
    case .Paren_Right: unimplemented()
    case .Plus: unimplemented()
    case .Semicolon: unimplemented()
    case .Slash: unimplemented()
    case .Star: unimplemented()
    case .Keyword_Asm: unimplemented()
    case .Keyword_Enum: unimplemented()
    case .Keyword_Print:   emit_print(p)
    case .Keyword_Println: emit_print(p, true)
    case .Keyword_Struct: unimplemented()
    case .Keyword_Using: unimplemented()
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
