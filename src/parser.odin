#+private file
package main

import "core:fmt"
import "core:log"
import "core:slice"
import "core:strconv"
import "core:strings"

@(private)
parser :: proc() {
    // Note: If a global error has been found, like code that shouldn't be
    // in the global scope, an error report should be posted and the second
    // compilation step shouldn't run.

    // First pass in compilation makes sure all files are loaded correctly.
    for filepath, source in source_files {
        parser := start_parser(tokenize(source, filepath))
        p := &parser

        for {
            token := next(p)
            if token.kind == .EOF { break }

            #partial switch token.kind {
                case .Symbol: {
                    expect(p, .Colon_Colon)
                    switch {
                    case allow(p, .Paren_Left):     register_procedure(p, token)
                    case allow(p, .Keyword_Enum):   unimplemented()
                    case allow(p, .Keyword_Struct): unimplemented()
                    case :                          unimplemented()
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

        for {
            token := next(p)
            if token.kind == .EOF { break }

            #partial switch token.kind {
                case .Symbol: {
                    allow(p, .Colon_Colon)

                    if allow(p, .Paren_Left) {
                        start_parsing_procedure(p, token)

                        for !is_eof(p) && !allow(p, .Semicolon) {
                            token := next(p)
                            parse_token(p, token)
                        }

                        end_parsing_procedure(p)
                    }
                }
            }
        }

        free_all(context.temp_allocator)
    }
}

Parser :: struct {
    tokens:         []Token,
    offset:         int,
    max_offset:     int,
    previous:       ^Token,
    current:        ^Token,
    current_proc:   ^Procedure,
}

start_parser :: proc(t: []Token) -> (p: Parser) {
    p.tokens = t
    p.offset = 0
    p.max_offset = len(t) - 1
    p.previous = &t[0]
    p.current = &t[0]
    return
}

next :: proc(p: ^Parser) -> ^Token {
    p.offset = min(p.offset + 1, p.max_offset)
    p.previous, p.current = p.current, &p.tokens[p.offset]
    return p.previous
}

expect :: proc(p: ^Parser, kind: Token_Kind, loc := #caller_location) -> ^Token {
    token := next(p)
    if token.kind != kind {
        // TODO: add error
        fmt.println(loc)
        assert(false)
    }
    return token
}

allow :: proc(p: ^Parser, kind: Token_Kind) -> bool {
    if p.current.kind == kind {
        next(p)
        return true
    }
    return false
}

peek :: proc(p: ^Parser) -> Token_Kind {
    return p.current.kind
}

emit :: proc(p: ^Parser, op: Operation) {
    append(&p.current_proc.ops, op)
}

is_eof :: proc(p: ^Parser) -> (result: bool) {
    return p.current.kind == .EOF || p.offset >= p.max_offset
}

is_parsing_procedure :: proc(p: ^Parser) -> (result: bool) {
    return p.current_proc != nil
}

get_location :: proc(t: ^Token) -> Location {
    return Location{file = t.file, offset = t.start}
}

start_parsing_procedure :: proc(p: ^Parser, t: ^Token) {
    name := t.source

    // Register arity and results to support polymorphism
    for !is_eof(p) && !allow(p, .Paren_Right) { next(p) }

    if ok := name in the_program.procedures; ok {
        p.current_proc = &the_program.procedures[name]
    }
}

end_parsing_procedure :: proc(p: ^Parser) {
    p.current_proc = nil
}

parse_token :: proc(p: ^Parser, token: ^Token) {
    // TODO: add proper error
    assert(is_parsing_procedure(p))

    op := Operation{loc = get_location(token)}

    switch token.kind {
    case .Invalid:
        // The tokenizer couldn't figure out what this token meant, so if there's a
        // bug, it's in that part of the code.
        log.errorf(ERROR_INVALID_TOKEN, token)
        assert(false)
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

    case .Symbol:
        // Note: Identifiers can be variables, bindings, constants or even other procedures, but they
        // also can be unknown. The order I want to have is to search for bindings first, variables second,
        // constants third and lastly, a procedure.
        parsed := false
        name := token.source

        // if ip, ok = is_identifier_binding(name); ok { return }
        //if ip, ok = is_identifier_variable(name); ok { return }
        //if ip, ok = is_identifier_constant(name); ok { return }
        if e, ok := the_program.procedures[name]; ok {
            op.variant = Op_Call_Proc{name = name, addr = e.addr}
            emit(p, op)
        }

    case .Lit_False, .Lit_True:
        op.variant = Op_Push_Bool{value = token.kind == .Lit_True}
        emit(p, op)
    case .Lit_Integer:
        op.variant = Op_Push_Integer{value = strconv.atoi(token.source)}
        emit(p, op)
    case .Lit_Float:
        op.variant = Op_Push_Float{value = strconv.atof(token.source)}
        emit(p, op)
    case .Lit_Character:
        unimplemented()
    case .Lit_String:
        op.variant = Op_Push_String{value = token.source}
        emit(p, op)
    case .Any, .Bool, .Float, .Int, .Quote, .String, .Uint,
            .F64, .F32, .S64, .S32, .S16, .S8,
            .U64, .U32, .U16, .U8:
        op.variant = Op_Push_Type{token.source}
        emit(p, op)
    case .Brace_Left:
        new_quote: Procedure
        new_quote.name = "quote"
        new_quote.addr = len(the_program.quotes)
        new_quote.ops = make([dynamic]Operation)
        new_quote.convention = .Anonymous
        new_quote.parent = p.current_proc
        new_quote.token = token^

        append(&the_program.quotes, new_quote)
        quote_to_parse := &the_program.quotes[len(the_program.quotes) - 1]
        old_proc := p.current_proc
        p.current_proc = quote_to_parse

        contents := strings.builder_make()
        strings.write_string(&contents, "{ ")

        for !allow(p, .Brace_Right) {
            token := next(p)
            format := token.kind == .Lit_String ? "\\\"{}\\\" " : "{} "
            fmt.sbprintf(&contents, format, token.source)
            parse_token(p, token)
        }
        fmt.sbprint(&contents, "}")
        p.current_proc = old_proc
        op.variant = Op_Push_Quote{
            contents = strings.to_string(contents),
            procedure = quote_to_parse,
        }
        emit(p, op)
    case .Brace_Right:
        assert(false)
    case .Bracket_Left:
        assert(false)
    case .Bracket_Right:
        assert(false)

    case .Equal:
        op.variant = Op_Binary{operation = .eq}
        emit(p, op)
    case .Not_Equal:
        op.variant = Op_Binary{operation = .ne}
        emit(p, op)
    case .Greater:
        op.variant = Op_Binary{operation = .gt}
        emit(p, op)
    case .Greater_Equal:
        op.variant = Op_Binary{operation = .ge}
        emit(p, op)
    case .Less:
        op.variant = Op_Binary{operation = .lt}
        emit(p, op)
    case .Less_Equal:
        op.variant = Op_Binary{operation = .le}
        emit(p, op)
    case .Question:
        op.variant = Op_Push_Type{"bool"}
        emit(p, op)
        op.variant = Op_Cast{}
        emit(p, op)
    case .Minus:
        op.variant = Op_Binary{operation = .minus}
        emit(p, op)
    case .Minus_Minus:
        op.variant = Op_Unary{operation = .minus_minus}
        emit(p, op)
    case .Percentage:
        op.variant = Op_Binary{operation = .modulo}
        emit(p, op)
    case .Plus:
        op.variant = Op_Binary{operation = .plus}
        emit(p, op)
    case .Plus_Plus:
        op.variant = Op_Unary{operation = .plus_plus}
        emit(p, op)
    case .Slash:
        op.variant = Op_Binary{operation = .divide}
        emit(p, op)
    case .Star:
        op.variant = Op_Binary{operation = .multiply}
        emit(p, op)

    case .Dash_Dash_Dash, .Paren_Left, .Paren_Right, .Semicolon:
        assert(false, "Can't parse within a procedure")
    case .Keyword_Apply:
        op.variant = Op_Apply{}
        emit(p, op)
    case .Keyword_And:
        op.variant = Op_Binary{operation = .and}
        emit(p, op)
    case .Keyword_Or:
        op.variant = Op_Binary{operation = .or}
        emit(p, op)

    case .Cast:
        op.variant = Op_Cast{}
        emit(p, op)
    case .If:
        op.variant = Op_If{has_else = true}
        emit(p, op)
    case .Times:
        op.variant = Op_Times{}
        emit(p, op)
    case .Keyword_Dup:
        op.variant = Op_Dup{}
        emit(p, op)
    case .Keyword_Enum:
        unimplemented()
    case .Keyword_Print, .Keyword_Println:
        op.variant = Op_Print{newline = token.kind == .Keyword_Println}
        emit(p, op)
    case .Keyword_Struct:
        unimplemented()
    case .Keyword_Swap:
        op.variant = Op_Swap{}
        emit(p, op)
    case .Keyword_Type:
        assert(false, "Can't parse 'type' within procedure")
    case .Keyword_Typeof:
        op.variant = Op_Typeof{}
        emit(p, op)
    case .Keyword_Using:
        unimplemented()
    }
}

register_procedure :: proc(p: ^Parser, t: ^Token, loc := #caller_location) {
    name := t.source
    ok := name in the_program.procedures
    assert(!ok)

    new_proc: Procedure
    new_proc.addr = len(the_program.procedures)
    new_proc.called = t.source == "main"
    new_proc.loc = get_location(t)
    new_proc.name = name
    new_proc.entities = make(Entity_Table)
    new_proc.ops = make([dynamic]Operation, 0, 16)
    new_proc.token = t^

    allow(p, .Paren_Left)
    has_results := false

    // Parse the arity and result
    if !allow(p, .Paren_Right) {
        parsing_params := true

        for {
            token := next(p)
            arity := parsing_params ? &new_proc.params : &new_proc.results
            type: Type

            #partial switch token.kind {
                case .Dash_Dash_Dash: parsing_params = false; continue
                case .Any: type.variant = Type_Any{}
                case .Bool: type.variant = Type_Boolean{}
                case .F64: type.variant = Type_Float{}; type.size = 64
                case .F32: type.variant = Type_Float{}; type.size = 32
                case .Float: type.variant = Type_Float{}; type.size = word_size_in_bits
                case .Int: type.variant = Type_Integer{is_signed = true}; type.size = word_size_in_bits
                case .Quote: type.variant = Type_Quote{}
                case .S64: type.variant = Type_Integer{is_signed = true}; type.size = 64
                case .S32: type.variant = Type_Integer{is_signed = true}; type.size = 32
                case .S16: type.variant = Type_Integer{is_signed = true}; type.size = 16
                case .S8: type.variant = Type_Integer{is_signed = true}; type.size = 8
                case .String: type.variant = Type_String{is_cstring = false}
                case .U64: type.variant = Type_Integer{is_signed = false}; type.size = 64
                case .U32: type.variant = Type_Integer{is_signed = false}; type.size = 32
                case .U16: type.variant = Type_Integer{is_signed = false}; type.size = 16
                case .U8: type.variant = Type_Integer{is_signed = false}; type.size = 8
                case .Uint: type.variant = Type_Integer{is_signed = false}; type.size = word_size_in_bits
                case: fmt.assertf(false, "Failed at token: {}", token)
            }

            append(arity, type)
            if allow(p, .Paren_Right) { break }
        }
    }

    for !allow(p, .Semicolon) { next(p) }
    the_program.procedures[name] = new_proc
}
