package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"

Arity_B :: distinct [dynamic]Type_B

Calling_Convention :: enum u8 {
    Invalid = 0,
    Stanczyk,
    CDecl,
    Anonymous,
}

Entity_Constant :: struct {
    kind: Token_Kind_B,
    value: union { f64, i64, string, u64 },
}

Entity_Procedure :: struct {
    parapoly: bool,
    params: Arity_B,
    results: Arity_B,
}

Entity_Variable :: struct {}

Entity_Variant :: union {
    Entity_Constant,
    Entity_Procedure,
    Entity_Variable,
}

Entity :: struct {
    addr:      uint,
    pos:       Position,
    variant:   Entity_Variant,
    name:      string,
    procedure: ^Procedure_B,
    is_global: bool,
}

Entity_Array :: distinct [dynamic]Entity

Internal_Procedure :: enum {
    Drop, Dup, Print, Println, Swap,
}

Procedure_B :: struct {
    using pos:  Position,
    addr:       uint,
    name:       string,
    convention: Calling_Convention,
    entities:   Entity_Array,
    local_ip:   uint,

    parent:  ^Procedure_B,
    is_global: bool,
}

Parser_B :: struct {
    scopes:         map[string]^Procedure_B,
    curr_procedure: ^Procedure_B,
    prev_token:     Token_B,
    curr_token:     Token_B,
    tokenizer:      Tokenizer_B,

    sim: Simulation,

    filename: string,
    errorf: proc(p: ^Parser_B, pos: Position, format: string,
                 args: ..any, loc := #caller_location) -> !,
}

global_errorf :: proc(format: string, args: ..any, loc := #caller_location) {
    fmt.eprintf("compilation error: ")
    fmt.eprintf(format, ..args)
    fmt.eprintln()
    when ODIN_DEBUG { fmt.eprintln("called from", loc) }
    os.exit(1)
}

default_errorf :: proc(
    p: ^Parser_B, pos: Position, format: string,
    args: ..any, loc := #caller_location,
) -> ! {
    fmt.eprintf("%s(%d:%d): ", p.filename, pos.line, pos.column)
    fmt.eprintf(format, ..args)
    fmt.eprintln()
    when ODIN_DEBUG { fmt.eprintln("called from", loc) }
    os.exit(1)
}

parse :: proc() {
    p := &Parser_B{}
    simulation_init(&p.sim)

    if p.errorf == nil {
        p.errorf = default_errorf
    }

    global := push_procedure(p, "", nil)
    defer pop_procedure(p)

    for filename, data in source_files {
        p.filename, _ = filepath.abs(filename)
        tokenizer_init(&p.tokenizer, p.filename, data)
        next(p)

        loop: for {
            token := next(p)

            #partial switch token.kind {
                case .Using: {
                    for allow(p, .Word) {
                        // TODO: Add these files to the source_files global
                        //token := p.prev_token
                    }
                    expect(p, .Semicolon)
                }
                case .Colon_Colon, .Colon_Equal: declare(p, token.kind)
                case .EOF: break loop
                case: p->errorf(
                    token.pos,
                    "unexpected token of type %s",
                    token_to_string(token),
                )
            }
        }
    }

    assert(p.curr_procedure == global)

    for e in global.entities {
        if e.name == "main" {
            gen.main_proc_addr = e.addr
            break
        }
    }

    if gen.main_proc_addr == 0 {
        global_errorf("main not defined in source files")
    }

    gen_bootstrap()

    for filename, data in source_files {
        p.filename, _ = filepath.abs(filename)
        tokenizer_init(&p.tokenizer, p.filename, data)
        next(p)

        parsing_loop: for {
            token := next(p)

            #partial switch token.kind {
                case .EOF: break parsing_loop
                case .Colon_Colon: {
                    // We only care of parsing procedures here.
                    name_token := next(p)

                    if allow(p, .Paren_Left) {
                        name := name_token.text
                        params, results := Arity_B{}, Arity_B{}
                        parse_proc_args(p, &params, &results)
                        ent: ^Entity
                        // TODO: support poly
                        for &e in global.entities {
                            if e.name == name {
                                ep := e.variant.(Entity_Procedure)
                                if slice.equal(ep.params[:], params[:]) && slice.equal(ep.results[:], results[:]) {
                                    ent = &e
                                    break
                                }
                            }
                        }
                        if ent == nil { p->errorf(name_token.pos, "procedure not found") }
                        parse_procedure(p, name, ent)
                    } else {
                        escape_loop: for {
                            token := next(p)
                            if token.kind == .Semicolon { break escape_loop }
                        }
                    }
                }
            }
        }
    }

    gen_file()
}

next :: proc(p: ^Parser_B) -> Token_B {
    token, err := get_next_token(&p.tokenizer)
    if err != nil && token.kind != .EOF {
        p->errorf(token.pos, "found invalid token: %v", err)
    }
    p.prev_token, p.curr_token = p.curr_token, token
    return p.prev_token
}

expect :: proc(p: ^Parser_B, kind: Token_Kind_B) -> Token_B {
    token := next(p)

    if token.kind != kind {
        p->errorf(
            token.pos,
            "expected %q, got %s",
            token_string_table[kind],
            token_to_string(token),
        )
    }

    return token
}

allow :: proc(p: ^Parser_B, kind: Token_Kind_B) -> bool {
    if p.curr_token.kind == kind {
        next(p)
        return true
    }
    return false
}

peek :: proc(p: ^Parser_B) -> Token_Kind_B {
    return p.curr_token.kind
}

find_symbol :: proc(p: ^Parser_B, token: Token_B) -> (ents: Entity_Array) {
    name := token.text
    check_proc := p.curr_procedure
    ok := false
    for check_proc != nil && !ok {
        for e in check_proc.entities {
            if e.name == name {
                append(&ents, e)
                ok = true
            }
        }
        if !ok { check_proc = check_proc.parent }
    }
    if !ok { p->errorf(token.pos, "undeclared symbol '%s'", name) }
    return
}

push_procedure :: proc(p: ^Parser_B, scope: string, ent: ^Entity) -> ^Procedure_B {
    new_proc := new_clone(Procedure_B{
        entities  = make(Entity_Array),
        name      = scope,
        is_global = scope == "",
        parent    = p.curr_procedure,
    })
    if ent != nil {
        new_proc.addr = ent.addr
        new_proc.pos = ent.pos
    }
    p.scopes[scope] = new_proc
    p.curr_procedure = new_proc
    return new_proc
}

pop_procedure :: proc(p: ^Parser_B) {
    p.curr_procedure = p.curr_procedure.parent
}

declare :: proc(p: ^Parser_B, start_token_kind: Token_Kind_B) {
    c := p.curr_procedure
    name_token := expect(p, .Word)
    name := name_token.text
    entity := Entity{
        pos = name_token.pos,
        procedure = c,
        is_global = c.is_global,
    }

    if allow(p, .Paren_Left) {
        eproc := Entity_Procedure{}
        parse_proc_args(p, &eproc.params, &eproc.results)

        body_loop: for {
            token := next(p)

            #partial switch token.kind {
                case .EOF: p->errorf(token.pos, "unexpected end of file")
                case .Semicolon: break body_loop
            }
        }

        entity.variant = eproc
    } else {
        #partial switch start_token_kind {
            case .Colon_Colon: {
                entity.variant = Entity_Constant{}
                for {
                    token := next(p)
                    if token.kind == .Semicolon { break }
                }
            }
            case .Colon_Equal: {
                entity.variant = Entity_Variable{}
                for {
                    token := next(p)
                    if token.kind == .Semicolon { break }
                }
            }
        }
    }

    // TODO: add check for redeclaration
    // if name in c.entities {
    //     ppos := c.entities[name].pos
    //     p->errorf(
    //         name_token.pos, "redeclaration of '%s' in %s(%d:%d)",
    //         name, ppos.filename, ppos.line, ppos.column,
    //     )
    // }

    if c.is_global {
        gen.global_ip += 1
        entity.addr = gen.global_ip
    } else {
        c.local_ip += 1
        entity.addr = c.local_ip
    }

    entity.name = name
    append(&c.entities, entity)
}

parse_proc_args :: proc(p: ^Parser_B, params, results: ^Arity_B) {
    append_to_arity :: proc(a: ^Arity_B, k: Type_Kind_B, n: string = "") {
        if a != nil { append(a, Type_B{ kind = k, name = n }) }
    }

    if !allow(p, .Paren_Right) {
        arity := params

        arity_loop: for {
            token := next(p)

            #partial switch token.kind {
                case .Paren_Right: break arity_loop
                case .Dash_Dash_Dash: arity = results
                case .Word: append_to_arity(arity, .Parapoly, token.text )
                case .Any: append_to_arity(arity, .Any)
                case .Bool: append_to_arity(arity, .Bool)
                case .Float: append_to_arity(arity, .Float)
                case .Int: append_to_arity(arity, .Int)
                case .Quote: unimplemented()
                case .String: append_to_arity(arity, .String)
                case .Uint: append_to_arity(arity, .Uint)
                case: p->errorf(token.pos, "unexpected token %s", token_to_string(token))
            }
        }
    }
}

parse_procedure :: proc(p: ^Parser_B, name: string, ent: ^Entity) {
    entp := ent.variant.(Entity_Procedure)
    push_procedure(p, name, ent)
    gen_proc(p.curr_procedure, .Head)

    for param in entp.params {
        p.sim->push(param.kind)
    }

    body_loop: for {
        if !parse_token(p, next(p)) {
            break body_loop
        }
    }

    if len(p.sim.stack) != len(entp.results) {
        p->errorf(
            ent.pos, "mismatched results in procedure {}\n\tExpected: {},\tHave: {}",
            ent.name,
            entp.results,
            p.sim.stack,
        )
    }

    gen_proc(p.curr_procedure, .Tail)
    pop_procedure(p)
    p.sim->clear()
}

parse_token :: proc(p: ^Parser_B, token: Token_B) -> bool {
    switch token.kind {
    case .EOF, .Invalid, .Using, .Colon_Colon,
            .Colon_Equal, .Dash_Dash_Dash:
        p->errorf(
            token.pos,
            "invalid token as procedure body %s",
            token_to_string(token),
        )
    case .Semicolon: return false

    case .Word:
        // TODO: Temporarily we're looking for known words
        // these will be Stanczyk procedures
        switch token.text {
        case "drop":
            p.sim->pop()
            gen_internal_proc_call(.Drop)
        case "dup":
            t := p.sim->pop()
            p.sim->push(t)
            p.sim->push(t)
            gen_internal_proc_call(.Dup)
        case "print":
            t := p.sim->pop()
            gen_internal_proc_call(.Print, t)
        case "println":
            t := p.sim->pop()
            gen_internal_proc_call(.Println, t)
        case "swap":
            x := p.sim->pop()
            y := p.sim->pop()
            p.sim->push(x)
            p.sim->push(y)
            gen_internal_proc_call(.Swap)
        case :
            ents := find_symbol(p, token)

            if len(ents) == 1 {
                ent := ents[0]
                switch v in ent.variant {
                case Entity_Constant: // TODO: handle
                case Entity_Variable: // TODO: handle
                case Entity_Procedure:
                    #reverse for param in v.params {
                        t := p.sim->pop()
                        if t != param.kind {
                            p->errorf(token.pos, "mismatched parameter")
                        }
                    }

                    for result in v.results {
                        p.sim->push(result.kind)
                    }

                    gen_proc_call(ent.addr)
                }
            } else {
                // NOTE: This is always a collection of procedures,
                // as constants and variables are not polymorphistic.
                Match_Stats :: struct {
                    entity: Entity,
                    // the stack matches exactly by the number of parameters required for this
                    // procedure to be called. We prioritize this!
                    exact_number_of_params: bool,
                }
                possible_matches := make([dynamic]Match_Stats, 0, 1, context.temp_allocator)
                ent: Entity
                ok: bool

                for e in ents {
                    test := e.variant.(Entity_Procedure)

                    if len(p.sim.stack) >= len(test.params) {
                        stack_copy := slice.clone(p.sim.stack[:], context.temp_allocator)
                        sim_test_stack := stack_copy[:len(test.params)]
                        proc_test_stack := make([dynamic]Type_Kind_B)

                        for param in test.params {
                            append(&proc_test_stack, param.kind)
                        }

                        if slice.equal(sim_test_stack, proc_test_stack[:]) {
                            append(&possible_matches, Match_Stats{
                                entity = e,
                                exact_number_of_params = len(p.sim.stack) == len(test.params),
                            })
                        }
                    }
                }

                if len(possible_matches) == 1 {
                    ent = possible_matches[0].entity
                    ok = true
                } else {
                    for m in possible_matches {
                        if m.exact_number_of_params {
                            ok = true
                            ent = m.entity
                            break
                        }
                    }
                }

                if !ok {
                    p->errorf(
                        token.pos,
                        "can't find a matching polymorphic procedure of name '{}' with current stack values: {}",
                        token.text, p.sim.stack,
                    )
                }

                v := ent.variant.(Entity_Procedure)

                #reverse for param in v.params {
                    t := p.sim->pop()
                    if t != param.kind {
                        p->errorf(token.pos, "mismatched parameter")
                    }
                }

                for result in v.results {
                    p.sim->push(result.kind)
                }

                gen_proc_call(ent.addr)
            }
        }

    case .Brace_Left:
        unimplemented()

    case .Brace_Right:
        unimplemented()

    case .Bracket_Left:
        unimplemented()

    case .Bracket_Right:
        unimplemented()

    case .Paren_Left:
        unimplemented()

    case .Paren_Right:
        unimplemented()

    case .Binary_Literal:
        unimplemented()

    case .Character_Literal:
        unimplemented()

    case .False_Literal:
        gen_push_literal(.Bool, token.text)
        p.sim->push(.Bool)

    case .Float_Literal:
        gen_push_literal(.Float, token.text)
        p.sim->push(.Float)

    case .Hex_Literal:
        unimplemented()

    case .Integer_Literal:
        gen_push_literal(.Int, token.text)
        p.sim->push(.Int)

    case .Octal_Literal:
        unimplemented()

    case .String_Literal:
        gen_push_literal(.String, token.text)
        p.sim->push(.String)

    case .True_Literal:
        gen_push_literal(.Bool, token.text)
        p.sim->push(.Bool)

    case .Add:
        t := p.sim->pop()
        p.sim->pop()
        if t == .String {
            gen_concat_string()
        } else {
            gen_arithmetic(t, .add)
        }
        p.sim->push(t)

    case .Divide:
        t := p.sim->pop()
        p.sim->pop()
        gen_arithmetic(t, .div)
        p.sim->push(t)

    case .Modulo:
        t := p.sim->pop()
        p.sim->pop()
        gen_arithmetic(t, .mod)
        p.sim->push(t)

    case .Multiply:
        t := p.sim->pop()
        p.sim->pop()
        gen_arithmetic(t, .mul)
        p.sim->push(t)

    case .Substract:
        t := p.sim->pop()
        p.sim->pop()
        gen_arithmetic(t, .sub)
        p.sim->push(t)

    case .Equal:
        t := p.sim->pop()
        p.sim->pop()
        gen_comparison(t, .eq)
        p.sim->push(.Bool)

    case .Greater_Equal:
        t := p.sim->pop()
        p.sim->pop()
        gen_comparison(t, .ge)
        p.sim->push(.Bool)

    case .Greater_Than:
        t := p.sim->pop()
        p.sim->pop()
        gen_comparison(t, .gt)
        p.sim->push(.Bool)

    case .Less_Equal:
        t := p.sim->pop()
        p.sim->pop()
        gen_comparison(t, .le)
        p.sim->push(.Bool)

    case .Less_Than:
        t := p.sim->pop()
        p.sim->pop()
        gen_comparison(t, .lt)
        p.sim->push(.Bool)

    case .Not_Equal:
        t := p.sim->pop()
        p.sim->pop()
        gen_comparison(t, .ne)
        p.sim->push(.Bool)

    case .Any:
        unimplemented()

    case .Bool:
        unimplemented()

    case .Float:
        unimplemented()

    case .Int:
        unimplemented()

    case .Quote:
        unimplemented()

    case .String:
        unimplemented()

    case .Uint:
        unimplemented()

    }

    return true
}
