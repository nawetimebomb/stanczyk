package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strconv"
import "core:strings"

Arity :: distinct [dynamic]Type

Entity_Binding :: struct {
    kind: Type_Kind,
}

Entity_Constant :: struct {
    kind: Token_Kind,
    value: union { f64, i64, string, u64 },
}

Entity_Function :: struct {
    inputs:  Arity,
    outputs: Arity,

    parapoly:    bool,
    polymorphic: bool,
}

Entity_Variable :: struct {}

Entity_Variant :: union {
    Entity_Binding,
    Entity_Constant,
    Entity_Function,
    Entity_Variable,
}

Entity :: struct {
    using pos: Position,
    address:   uint,
    name:      string,
    is_global: bool,

    variant: Entity_Variant,
}

Entities :: distinct [dynamic]Entity

Function :: struct {
    using pos: Position,
    address:   uint,
    name:      string,

    entities:    ^Entities,
    local_ip:    uint,

    code:   strings.Builder,
    indent: int,

    parent:  ^Function,
    is_global: bool,
}

Parser :: struct {
    scopes: [dynamic]Entities,

    curr_function:  ^Function,
    prev_token:     Token,
    curr_token:     Token,
    tokenizer:      Tokenizer,

    sim: Simulation,

    errorf: proc(p: ^Parser, pos: Position, format: string,
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
    p: ^Parser, pos: Position, format: string,
    args: ..any, loc := #caller_location,
) -> ! {
    fmt.eprintf("%s(%d:%d): ", pos.filename, pos.line, pos.column)
    fmt.eprintf(format, ..args)
    fmt.eprintln()
    when ODIN_DEBUG { fmt.eprintln("called from", loc) }
    os.exit(1)
}

gscope: ^Entities

parse :: proc() {
    p := &Parser{}
    simulation_init(&p.sim)

    if p.errorf == nil {
        p.errorf = default_errorf
    }

    gscope = push_function(p, "", nil)
    defer pop_function(p)

    for filename, data in source_files {
        tokenizer_init(&p.tokenizer, filename, data)
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

    assert(len(p.scopes) == 1)

    for e in gscope {
        if e.name == "main" {
            gen.main_func_address = e.address
            break
        }
    }

    gen_bootstrap()

    for filename, data in source_files {
        tokenizer_init(&p.tokenizer, filename, data)
        next(p)

        parsing_loop: for {
            token := next(p)

            #partial switch token.kind {
                case .EOF: break parsing_loop
                case .Colon_Colon: {
                    // We only care of parsing functions here.
                    name_token := next(p)

                    if allow(p, .Paren_Left) {
                        name := name_token.text
                        inputs, outputs := Arity{}, Arity{}
                        parse_proc_args(p, &inputs, &outputs)
                        ent: ^Entity

                        for &e in gscope {
                            if e.name == name {
                                ep := e.variant.(Entity_Function)
                                inputs_match := slice.equal(ep.inputs[:], inputs[:])
                                outputs_match := slice.equal(ep.outputs[:], outputs[:])
                                if inputs_match && outputs_match {
                                    ent = &e
                                    break
                                }
                            }
                        }
                        if ent == nil {
                            p->errorf(name_token.pos, "function not found")
                        }
                        parse_function(p, name, ent)
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

    gen_compilation_unit()
}

next :: proc(p: ^Parser) -> Token {
    token, err := get_next_token(&p.tokenizer)
    if err != nil && token.kind != .EOF {
        p->errorf(token.pos, "found invalid token: %v", err)
    }
    p.prev_token, p.curr_token = p.curr_token, token
    return p.prev_token
}

expect :: proc(p: ^Parser, kind: Token_Kind) -> Token {
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

allow :: proc(p: ^Parser, kind: Token_Kind) -> bool {
    if p.curr_token.kind == kind {
        next(p)
        return true
    }
    return false
}

peek :: proc(p: ^Parser) -> Token_Kind {
    return p.curr_token.kind
}

find_word_meaning :: proc(p: ^Parser, token: Token) -> (ents: Entities) {
    name := token.text
    check_index := len(p.scopes) - 1
    curr_scope := p.scopes[check_index]
    found := false
    for check_index >= 0 && !found {
        for e in curr_scope {
            if e.name == name {
                append(&ents, e)
                found = true
            }
        }
        if !found {
            check_index -= 1
            curr_scope = p.scopes[check_index]
        }
    }
    if !found { p->errorf(token.pos, "undeclared symbol '%s'", name) }
    return
}

push_function :: proc(p: ^Parser, name: string, ent: ^Entity) -> ^Entities {
    scope := push_scope(p)
    new_proc := new_clone(Function{
        entities  = &p.scopes[len(p.scopes) - 1],
        name      = name,
        is_global = name == "",
        parent    = p.curr_function,
    })

    if ent != nil {
        new_proc.address = ent.address
        new_proc.pos = ent.pos
    }

    p.curr_function = new_proc
    return scope
}

pop_function :: proc(p: ^Parser) {
    p.curr_function = p.curr_function.parent
    pop_scope(p)
}

push_scope :: proc(p: ^Parser) -> ^Entities {
    append(&p.scopes, make(Entities))
    return &p.scopes[len(p.scopes) - 1]
}

pop_scope :: proc(p: ^Parser) {
    pop(&p.scopes)
}

declare :: proc(p: ^Parser, start_token_kind: Token_Kind) {
    name_token := expect(p, .Word)
    name := name_token.text
    entity := Entity{
        pos = name_token.pos,
        is_global = true,
    }

    if allow(p, .Paren_Left) {
        eproc := Entity_Function{}
        parse_proc_args(p, &eproc.inputs, &eproc.outputs)

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

    entity.address = gen_global_ip()
    entity.name = name
    append(gscope, entity)
}

parse_proc_args :: proc(p: ^Parser, inputs, outputs: ^Arity) {
    append_to_arity :: proc(a: ^Arity, k: Type_Kind, n: string = "") {
        if a != nil { append(a, Type{ kind = k, name = n }) }
    }

    if !allow(p, .Paren_Right) {
        arity := inputs

        arity_loop: for {
            token := next(p)

            #partial switch token.kind {
                case .Paren_Right: break arity_loop
                case .Dash_Dash_Dash: arity = outputs
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

parse_function :: proc(p: ^Parser, name: string, e: ^Entity) {
    ef := e.variant.(Entity_Function)
    push_function(p, name, e)
    f := p.curr_function
    gen_function_declaration(f)
    gen_function(f, .Head)

    for param in ef.inputs {
        p.sim->push(param.kind)
    }

    body_loop: for {
        if !parse_token(p, next(p)) {
            break body_loop
        }
    }

    if len(p.sim.stack) != len(ef.outputs) {
        p->errorf(
            e.pos, "mismatched outputs in function {}\n\tExpected: {},\tHave: {}",
            e.name,
            ef.outputs,
            p.sim.stack,
        )
    }

    gen_function(f, .Tail)
    pop_function(p)
    p.sim->clear()
}

parse_token :: proc(p: ^Parser, token: Token) -> bool {
    f := p.curr_function

    switch token.kind {
    case .EOF, .Invalid, .Using, .Colon_Colon,
            .Colon_Equal, .Dash_Dash_Dash:
        p->errorf(
            token.pos,
            "invalid token as function body %s",
            token_to_string(token),
        )
    case .Semicolon: return false

    case .Word:
        // TODO: Temporarily we're looking for known words
        // these will be Stanczyk functions
        switch token.text {
        case "drop":
            p.sim->pop()
            gen_drop(f)
        case "dup":
            t := p.sim->pop()
            p.sim->push(t)
            p.sim->push(t)
            gen_dup(f)
        case "print":
            t := p.sim->pop()
            gen_literal_c(f, "print({}_t);", type_to_cname(t))
        case "println":
            t := p.sim->pop()
            gen_literal_c(f, "println({}_t);", type_to_cname(t))
        case "swap":
            x := p.sim->pop()
            y := p.sim->pop()
            p.sim->push(x)
            p.sim->push(y)
            gen_swap(f)
        case :
            ents := find_word_meaning(p, token)

            if len(ents) == 0 {
                p->errorf(token.pos, "can't find meaning of word '%s'", token.text)
            }

            if len(ents) == 1 {
                ent := ents[0]
                switch v in ent.variant {
                case Entity_Binding:
                    gen_push_binding(f, ent.address)
                    p.sim->push(v.kind)
                case Entity_Constant: // TODO: handle
                case Entity_Variable: // TODO: handle
                case Entity_Function:
                    #reverse for param in v.inputs {
                        t := p.sim->pop()
                        if t != param.kind {
                            p->errorf(token.pos, "mismatched parameter")
                        }
                    }

                    for result in v.outputs {
                        p.sim->push(result.kind)
                    }

                    gen_function_call(f, ent.address)
                }
            } else {
                // NOTE: This is always a collection of functions,
                // as constants and variables are not polymorphistic.
                Match_Stats :: struct {
                    entity: Entity,
                    // the stack matches exactly by the number of parameters required for this
                    // function to be called. We prioritize this!
                    exact_number_of_inputs: bool,
                }
                possible_matches := make([dynamic]Match_Stats, 0, 1, context.temp_allocator)
                ent: Entity
                ok: bool

                for e in ents {
                    test := e.variant.(Entity_Function)

                    if len(p.sim.stack) >= len(test.inputs) {
                        stack_copy := slice.clone(p.sim.stack[:], context.temp_allocator)
                        sim_test_stack := stack_copy[:len(test.inputs)]
                        proc_test_stack := make([dynamic]Type_Kind)

                        for param in test.inputs {
                            append(&proc_test_stack, param.kind)
                        }

                        if slice.equal(sim_test_stack, proc_test_stack[:]) {
                            append(&possible_matches, Match_Stats{
                                entity = e,
                                exact_number_of_inputs = len(p.sim.stack) == len(test.inputs),
                            })
                        }
                    }
                }

                if len(possible_matches) == 1 {
                    ent = possible_matches[0].entity
                    ok = true
                } else {
                    for m in possible_matches {
                        if m.exact_number_of_inputs {
                            ok = true
                            ent = m.entity
                            break
                        }
                    }
                }

                if !ok {
                    p->errorf(
                        token.pos,
                        "can't find a matching polymorphic function of name '{}' with current stack values: {}",
                        token.text, p.sim.stack,
                    )
                }

                v := ent.variant.(Entity_Function)

                #reverse for param in v.inputs {
                    t := p.sim->pop()
                    if t != param.kind {
                        p->errorf(token.pos, "mismatched parameter")
                    }
                }

                for result in v.outputs {
                    p.sim->push(result.kind)
                }

                gen_function_call(f, ent.address)
            }
        }
    case .Let:
        scope := push_scope(p)
        words := make([dynamic]Token, context.temp_allocator)
        defer delete(words)
        gen_code_block(f, .start)

        for !allow(p, .Brace_Left) {
            token := expect(p, .Word)
            append(&words, token)
        }

        #reverse for word in words {
            t := p.sim->pop()
            address := get_local_address(f)
            append(scope, Entity{
                address = address,
                pos = word.pos,
                name = word.text,
                variant = Entity_Binding{kind = t},
            })
            gen_binding(f, address)
        }

    case .Brace_Left:
        unimplemented()

    case .Brace_Right:
        pop_scope(p)
        gen_code_block(f, .end)

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
        gen_push_bool(f, "SKFALSE")
        p.sim->push(.Bool)

    case .Float_Literal:
        gen_push_float(f, strconv.atof(token.text))
        p.sim->push(.Float)

    case .Hex_Literal:
        unimplemented()

    case .Integer_Literal:
        gen_push_int(f, strconv.atoi(token.text))
        p.sim->push(.Int)

    case .Octal_Literal:
        unimplemented()

    case .String_Literal:
        gen_push_string(f, token.text)
        p.sim->push(.String)

    case .True_Literal:
        gen_push_bool(f, "SKTRUE")
        p.sim->push(.Bool)

    case .Add:
        t := p.sim->pop()
        p.sim->pop()
        gen_add(f, t)
        p.sim->push(t)

    case .Divide:
        t := p.sim->pop()
        p.sim->pop()
        gen_divide(f, t)
        p.sim->push(t)

    case .Modulo:
        t := p.sim->pop()
        p.sim->pop()
        gen_modulo(f, t)
        p.sim->push(t)

    case .Multiply:
        t := p.sim->pop()
        p.sim->pop()
        gen_multiply(f, t)
        p.sim->push(t)

    case .Substract:
        t := p.sim->pop()
        p.sim->pop()
        gen_substract(f, t)
        p.sim->push(t)

    case .Equal:
        t := p.sim->pop()
        p.sim->pop()
        gen_equal(f, t)
        p.sim->push(.Bool)

    case .Greater_Equal:
        t := p.sim->pop()
        p.sim->pop()
        gen_greater_equal(f, t)
        p.sim->push(.Bool)

    case .Greater_Than:
        t := p.sim->pop()
        p.sim->pop()
        gen_greater_than(f, t)
        p.sim->push(.Bool)

    case .Less_Equal:
        t := p.sim->pop()
        p.sim->pop()
        gen_less_equal(f, t)
        p.sim->push(.Bool)

    case .Less_Than:
        t := p.sim->pop()
        p.sim->pop()
        gen_less_than(f, t)
        p.sim->push(.Bool)

    case .Not_Equal:
        t := p.sim->pop()
        p.sim->pop()
        gen_not_equal(f, t)
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

get_local_address :: proc(f: ^Function) -> (address: uint) {
    address = f.local_ip
    f.local_ip += 1
    return
}
