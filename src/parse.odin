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

Entity_Variable :: struct {}

Entity_Procedure :: struct {
    params: Arity_B,
    results: Arity_B,
}

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

Entity_Table :: distinct map[string]Entity

Internal_Procedure :: enum {
    Drop, Dup, Print, Println, Swap,
}

Procedure_B :: struct {
    addr:       uint,
    pos:        Position,
    name:       string,
    convention: Calling_Convention,
    entities:   Entity_Table,
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

    filename: string,
    errorf: proc(p: ^Parser_B, pos: Position, format: string,
                 args: ..any, loc := #caller_location) -> !,
}

Stack :: struct {
    pop: proc(s: ^Stack) -> (t: Type_Kind_B),
    push: proc(s: ^Stack, t: Type_Kind_B),
    values: [dynamic]Type_Kind_B,
}

sim_push :: proc(s: ^Stack, t: Type_Kind_B) {
    append(&s.values, t)
}

sim_pop :: proc(s: ^Stack) -> (t: Type_Kind_B) {
    return pop(&s.values)
}

global_errorf :: proc(format: string, args: ..any, loc := #caller_location) {
    fmt.eprintf("compilation error: ")
    fmt.eprintf(format, ..args)
    fmt.eprintln()
    when ODIN_DEBUG { fmt.eprintln("called from", loc) }
    os.exit(1)
}

default_errorf :: proc(
    p: ^Parser_B,
    pos: Position,
    format: string,
    args: ..any,
    loc := #caller_location,
) -> ! {
    fmt.eprintf("%s(%d:%d): ", p.filename, pos.line, pos.column)
    fmt.eprintf(format, ..args)
    fmt.eprintln()
    when ODIN_DEBUG { fmt.eprintln("called from", loc) }
    os.exit(1)
}

stack: Stack

parse :: proc() {
    p := &Parser_B{}
    stack.pop = sim_pop
    stack.push = sim_push
    stack.values = make([dynamic]Type_Kind_B, 0, 16)

    if p.errorf == nil {
        p.errorf = default_errorf
    }

    global := push_procedure(p, "")
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
                }
                case .Colon_Colon, .Colon_Equal: declare(p, token.kind)
                case .EOF: break loop
                case: p->errorf(token.pos,
                    "unexpected token of type %s",
                    token_to_string(token),
                )
            }
        }
    }

    assert(p.curr_procedure == global)

    if "main__main" not_in global.entities {
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
                    proc_name := strings.builder_make(context.temp_allocator)
                    name_token := next(p)

                    if allow(p, .Paren_Left) {
                        strings.write_string(&proc_name, name_token.text)

                        if !allow(p, .Paren_Right) {
                            strings.write_string(&proc_name, "_")

                            arity_loop: for {
                                token := next(p)

                                if token.kind == .Paren_Right {
                                    break arity_loop
                                } else if token.kind == .Dash_Dash_Dash {
                                    strings.write_string(&proc_name, "_")
                                } else {
                                    parse_argument(p, token, nil, &proc_name)
                                }
                            }
                        }

                        parsed_name := strings.to_string(proc_name)
                        if parsed_name == "main" { parsed_name = "main__main" }

                        if parsed_name in global.entities {
                            parse_procedure(p, parsed_name)
                        }
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

push_procedure :: proc(p: ^Parser_B, scope: string) -> ^Procedure_B {
    new_proc := new_clone(Procedure_B{
        entities  = make(Entity_Table),
        name      = scope,
        is_global = scope == "",
        parent    = p.curr_procedure,
    })
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
        entity_proc := Entity_Procedure{}
        proc_name := strings.builder_make(context.temp_allocator)
        strings.write_string(&proc_name, name)

        if !allow(p, .Paren_Right) {
            strings.write_string(&proc_name, "_")
            arity := &entity_proc.params

            arity_loop: for {
                token := next(p)

                if token.kind == .Paren_Right {
                    break arity_loop
                } else if token.kind == .Dash_Dash_Dash {
                    strings.write_string(&proc_name, "_")
                    arity = &entity_proc.results
                } else {
                    parse_argument(p, token, arity, &proc_name)
                }
            }
        }

        name = strings.clone(strings.to_string(proc_name))

        if name == "main" {
            // NOTE: "main" is always being used as the entry point of the codegen,
            // so the main Stanczyk procedure should always be called "main__main",
            // which is the function that the generator will call after doing the
            // initial bootstrapping and setup.
            delete(name)
            name = "main__main"
        }

        body_loop: for {
            token := next(p)

            #partial switch token.kind {
                case .EOF: p->errorf(token.pos, "unexpected end of file")
                case .Semicolon: break body_loop
            }
        }

        entity.variant = entity_proc
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

    if name in c.entities {
        previous_decl := c.entities[name]
        opos := previous_decl.pos
        p->errorf(
            name_token.pos, "redeclaration of '%s' in %s(%d:%d)",
            name, opos.filename, opos.line, opos.column,
        )
    }

    if c.is_global {
        entity.addr = gen.global_ip
        gen.global_ip += 1
    } else {
        entity.addr = c.local_ip
        c.local_ip += 1
    }

    entity.name = name
    c.entities[name] = entity
}

parse_argument :: proc(p: ^Parser_B, t: Token_B, a: ^Arity_B, s: ^strings.Builder) {
    type := Type_B{}

    #partial switch t.kind {
        case .Word: {
            type.kind = .Parapoly
            type.name = t.text
            fmt.sbprintf(s, "_%s", t.text)
        }
        case .Any: {
            type.kind = .Any
            strings.write_string(s, "_any")
        }
        case .Bool: {
            type.kind = .Bool
            strings.write_string(s, "_bool")
        }
        case .Float: {
            type.kind = .Float
            strings.write_string(s, "_float")
        }
        case .Int: {
            type.kind = .Int
            strings.write_string(s, "_int")
        }
        case .Quote: assert(false)
        case .String: {
            type.kind = .String
            strings.write_string(s, "_string")
        }
        case .Uint: {
            type.kind = .Uint
            strings.write_string(s, "_uint")
        }
        case: p->errorf(t.pos, "unexpected token %s", token_to_string(t))
    }

    if a != nil {
        append(a, type)
    }
}

parse_procedure :: proc(p: ^Parser_B, name: string) {
    push_procedure(p, name)
    gen_proc(p.curr_procedure, .Head)

    body_loop: for {
        token := next(p)

        switch token.kind {
        case .EOF, .Invalid, .Using, .Colon_Colon,
                .Colon_Equal, .Dash_Dash_Dash:
            p->errorf(
                token.pos,
                "invalid token as procedure body %s",
                token_to_string(token),
            )
        case .Semicolon: break body_loop

        case .Word:
            // TODO: Temporarily we're looking for known words
            // these will be Stanczyk procedures
            switch token.text {
            case "print":
                t := stack->pop()
                gen_internal_proc_call(.Print, t)
            case "println":
                t := stack->pop()
                gen_internal_proc_call(.Println, t)
            }

        case .Brace_Left:

        case .Brace_Right:

        case .Bracket_Left:

        case .Bracket_Right:

        case .Paren_Left:

        case .Paren_Right:

        case .Binary_Literal:

        case .Character_Literal:

        case .False_Literal:
            gen_push_literal(.Bool, token.text)
            stack->push(.Bool)

        case .Float_Literal:
            gen_push_literal(.Float, token.text)
            stack->push(.Float)

        case .Hex_Literal:

        case .Integer_Literal:
            gen_push_literal(.Int, token.text)
            stack->push(.Int)

        case .Octal_Literal:

        case .String_Literal:
            gen_push_literal(.String, token.text)
            stack->push(.String)

        case .True_Literal:
            gen_push_literal(.Bool, token.text)
            stack->push(.Bool)

        case .Add:
            r := stack->pop()
            l := stack->pop()
            gen_arithmetic(l, r, l, .add)
            stack->push(l)

        case .Divide:
            r := stack->pop()
            l := stack->pop()
            gen_arithmetic(l, r, l, .div)
            stack->push(l)

        case .Modulo:
            r := stack->pop()
            l := stack->pop()
            gen_arithmetic(l, r, l, .mod)
            stack->push(l)

        case .Multiply:
            r := stack->pop()
            l := stack->pop()
            gen_arithmetic(l, r, l, .mul)
            stack->push(l)

        case .Substract:
            r := stack->pop()
            l := stack->pop()
            gen_arithmetic(l, r, l, .sub)
            stack->push(l)

        case .Equal:

        case .Greater_Equal:

        case .Greater_Than:

        case .Less_Equal:

        case .Less_Than:

        case .Not_Equal:

        case .Any:

        case .Bool:

        case .Float:

        case .Int:

        case .Quote:

        case .String:

        case .Uint:

        }
    }
    gen_proc(p.curr_procedure, .Tail)
    pop_procedure(p)
}
