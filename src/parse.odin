package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strconv"
import "core:strings"

Arity :: distinct [dynamic]Type

Constant_Value :: union { bool, f64, int, string, u64 }

Entity_Binding :: struct {
    kind: Type_Kind,
}

Entity_Constant :: struct {
    kind: Type_Kind,
    value: Constant_Value,
}

Entity_C_Function :: struct {

}

Entity_Function :: struct {
    inputs:  Arity,
    outputs: Arity,

    has_any_input:  bool,
    is_parapoly:    bool,
    is_polymorphic: bool,
}

Entity_Variable :: struct {}

Entity_Variant :: union {
    Entity_Binding,
    Entity_Constant,
    Entity_C_Function,
    Entity_Function,
    Entity_Variable,
}

Entity :: struct {
    using pos: Position,
    address:   uint,
    name:      string,
    is_global: bool,
    token:     Token,

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

    curr_function: ^Function,
    prev_token:    Token,
    curr_token:    Token,
    tokenizer:     Tokenizer,

    rstack: Reference_Stack,
    tstack: Type_Stack,

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
    init_type_stack(&p.tstack)
    init_reference_stack(&p.rstack)

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
                case .Const: {
                    declare_const(p)
                }
                case .Fn: {
                    declare_func(p)
                    scope_level := 1

                    body_loop: for {
                        token := next(p)

                        #partial switch token.kind {
                            case .Const: scope_level += 1
                            case .Fn: scope_level += 1
                            case .EOF: p->errorf(
                                token.pos, "unexpected end of file",
                            )
                            case .Semicolon: {
                                scope_level -= 1
                                if scope_level == 0 { break body_loop }
                            }
                        }
                    }
                }
                case .EOF: break loop
                case: p->errorf(
                    token.pos, "unexpected token of type %s", token_to_string(token),
                )
            }
        }
    }

    assert(len(p.scopes) == 1)

    gen_bootstrap()

    for filename, data in source_files {
        tokenizer_init(&p.tokenizer, filename, data)
        next(p)

        parsing_loop: for {
            token := next(p)

            #partial switch token.kind {
                case .EOF: break parsing_loop
                case .Fn: {
                    name_token := expect(p, .Word)
                    parsing_entity: ^Entity
                    expect(p, .Paren_Left)

                    // Searching the function by its token
                    for &other in gscope {
                        if other.token == name_token {
                            parsing_entity = &other
                            break
                        }
                    }

                    if parsing_entity == nil {
                        p->errorf(
                            name_token.pos,
                            "compiler error failed to find Function entity",
                        )
                    }

                    skip_to_body: for {
                        if next(p).kind == .Paren_Right {
                            break skip_to_body
                        }
                    }

                    parse_function(p, name_token.text, parsing_entity)
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

find_entity :: proc(p: ^Parser, token: Token) -> Entity {
    possible_matches := make(Entities)
    defer delete(possible_matches)
    name := token.text
    curr_scope_index := len(p.scopes) - 1
    curr_scope := p.scopes[curr_scope_index]
    found := false

    for curr_scope_index >= 0 && !found {
        for check in curr_scope {
            if check.name == name {
                append(&possible_matches, check)
                found = true
            }
        }

        if !found {
            curr_scope_index -= 1
            curr_scope = p.scopes[max(curr_scope_index, 0)]
        }
    }

    switch len(possible_matches) {
    case 0: // Nothing found, so we error out
        p->errorf(token.pos, "undefined word '%s'", name)
    case 1: // Just one definition found, return
        return possible_matches[0]
    case :
        // Multiple entities found, need to figure out which one it is.
        // The good thing is that now we know this is a function, because
        // other types of values are not polymorphic.
        // We track the possible result by prioritizing the number of inputs
        // that the function can receive, but we also check for its arity.
        Match_Stats :: struct {
            entity: Entity,
            exact_number_inputs: bool,
        }
        matches := make([dynamic]Match_Stats, 0, 1)
        defer delete(matches)

        for other in possible_matches {
            test := other.variant.(Entity_Function)

            if len(p.tstack.v) >= len(test.inputs) {
                stack_copy := slice.clone(p.tstack.v[:])
                defer delete(stack_copy)
                sim_test_stack := stack_copy[:len(test.inputs)]
                func_test_stack := make([dynamic]Type_Kind)
                defer delete(func_test_stack)

                for input in test.inputs {
                    append(&func_test_stack, input.kind)
                }

                if slice.equal(sim_test_stack, func_test_stack[:]) {
                    append(&matches, Match_Stats{
                        entity = other,
                        exact_number_inputs = len(p.tstack.v) == len(test.inputs),
                    })
                }
            }
        }

        if len(matches) == 1 {
            // Found and there's only one that makes sense, so return it.
            return matches[0].entity
        } else {
            // Prioritize the one that has exact match of inputs.
            // This makes it so we can have a function with arity of one and another
            // with arity of more than one, but one of the types matches.
            for m in matches {
                if m.exact_number_inputs {
                    return m.entity
                }
            }
        }

        // Unfortunately we couldn't find a reliable result, so we error out.
        p->errorf(
            token.pos,
            "can't find a matching polymorphic function of name '{}' with current stack values: {}",
            token.text, p.tstack.v,
        )
    }

    return Entity{}
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
    if !found { p->errorf(token.pos, "undeclared word '%s'", name) }
    return
}

push_function :: proc(p: ^Parser, name: string, ent: ^Entity) -> ^Entities {
    scope := push_scope(p)
    new_func := new_clone(Function{
        entities  = scope,
        name      = name,
        is_global = name == "",
        parent    = p.curr_function,
    })

    if ent != nil {
        new_func.address = ent.address
        new_func.pos = ent.pos
    }

    p.curr_function = new_func
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

parse_function_head :: proc(p: ^Parser, ef: ^Entity_Function) {
    expect(p, .Paren_Left)

    if !allow(p, .Paren_Right) {
        arity := &ef.inputs

        arity_loop: for {
            token := next(p)

            #partial switch token.kind {
                case .Paren_Right: break arity_loop
                case .Dash_Dash_Dash: arity = &ef.outputs
                case .Word: {
                    ef.is_parapoly = true
                    append(arity, Type{.Parapoly, token.text})
                }
                case .Type_Literal: {
                    t := type_string_to_kind(token.text)
                    if t == .Any { ef.has_any_input = true }
                    append(arity, Type{t, token.text})
                }
                case: p->errorf(
                    token.pos, "unexpected token %s", token_to_string(token),
                )
            }
        }
    }
}

declare_const :: proc(p: ^Parser) {
    name_token := expect(p, .Word)
    name := name_token.text
    f := p.curr_function
    ec := Entity_Constant{}
    is_global := f.is_global
    address := is_global ? gen_global_address() : gen_local_address(f)
    scope := &p.scopes[len(p.scopes) - 1]
    inferred_type: Type_Kind
    temp_value_stack := make([dynamic]Constant_Value)
    defer delete(temp_value_stack)

    if allow(p, .Type_Literal) {
        ec.kind = type_string_to_kind(p.prev_token.text)
    }

    body_loop: for {
        token := next(p)

        #partial switch token.kind {
            case .EOF: p->errorf(token.pos, "unexpected end of file")
            case .Semicolon: break body_loop
            case .Word: {
                entity := find_entity(p, token)

                #partial switch v in entity.variant {
                case Entity_Constant:
                    if inferred_type != .Invalid && inferred_type != v.kind {
                        p->errorf(
                            token.pos,
                            "word '{}' of type '{}' cannot be used in expected type of {}",
                            entity.name, v.kind, inferred_type,
                        )
                    }

                    inferred_type = v.kind

                    #partial switch v.kind {
                        case .Float, .Int: append(&temp_value_stack, v.value)
                        case: {
                            ec.value = v.value
                            expect(p, .Semicolon)
                            break body_loop
                        }
                    }
                    case: p->errorf(token.pos, "'{}' is not a compile-time known constant")
                }
            }
            case .False_Literal: {
                ec.value = false
                inferred_type = .Bool
                expect(p, .Semicolon)
                break body_loop
            }
            case .Float_Literal: {
                append(&temp_value_stack, strconv.atof(token.text))
                if inferred_type == .Invalid {
                    inferred_type = .Float
                } else if inferred_type != .Float {
                    p->errorf(token.pos, "expected type {} in constant", inferred_type)
                }
            }
            case .Integer_Literal: {
                append(&temp_value_stack, strconv.atoi(token.text))
                if inferred_type == .Invalid {
                    inferred_type = .Int
                } else if inferred_type != .Int {
                    p->errorf(token.pos, "can't mix type of values in constant")
                }
            }
            case .String_Literal: {
                ec.value = token.text
                inferred_type = .String
                expect(p, .Semicolon)
                break body_loop
            }
            case .True_Literal: {
                ec.value = true
                inferred_type = .Bool
                expect(p, .Semicolon)
                break body_loop
            }
            case .Uint_Literal: {
                val, _ := strconv.parse_u64(token.text)
                append(&temp_value_stack, val)
                if inferred_type == .Invalid {
                    inferred_type = .Uint
                } else if inferred_type != .Uint {
                    p->errorf(token.pos, "can't mix type of values in constant")
                }
            }

            t1: u64 = 1000
            t2: u64 = 10
            result := t1 % t2

            case .Add, .Divide, .Modulo, .Multiply, .Substract: {
                v2 := pop(&temp_value_stack)
                v1 := pop(&temp_value_stack)
                #partial switch token.kind {
                    case .Add: {
                        #partial switch inferred_type {
                            case .Float: append(&temp_value_stack, v1.(f64) + v2.(f64))
                            case .Int: append(&temp_value_stack, v1.(int) + v2.(int))
                            case .Uint: append(&temp_value_stack, v1.(u64) + v2.(u64))
                        }
                    }
                    case .Divide: {
                        #partial switch inferred_type {
                            case .Float: append(&temp_value_stack, v1.(f64) / v2.(f64))
                            case .Int: append(&temp_value_stack, v1.(int) / v2.(int))
                            case .Uint: append(&temp_value_stack, v1.(u64) / v2.(u64))
                        }
                    }
                    case .Modulo: {
                        #partial switch inferred_type {
                            case .Float: p->errorf(
                                token.pos, "Opertor '%' only allowed with integers",
                            )
                            case .Int: append(&temp_value_stack, v1.(int) % v2.(int))
                            case .Uint: append(&temp_value_stack, v1.(u64) % v2.(u64))
                        }
                    }
                    case .Multiply: {
                        #partial switch inferred_type {
                            case .Float: append(&temp_value_stack, v1.(f64) * v2.(f64))
                            case .Int: append(&temp_value_stack, v1.(int) * v2.(int))
                        }
                    }
                    case .Substract: {
                        #partial switch inferred_type {
                            case .Float: append(&temp_value_stack, v1.(f64) - v2.(f64))
                            case .Int: append(&temp_value_stack, v1.(int) - v2.(int))
                        }
                    }
                }
            }
        }
    }

    if ec.kind == .Invalid {
        ec.kind = inferred_type
    } else if ec.kind != inferred_type {
        p->errorf(
            name_token,
            "type declaration of {} doesn't match value type of {} in constant '{}'",
            ec.kind, inferred_type, name,
        )
    }

    if len(temp_value_stack) > 0 {
        if len(temp_value_stack) != 1 {
            p->errorf(name_token, "values in constant don't compile to a single value")
        }

        ec.value = pop(&temp_value_stack)
    }

    if name == "main" {
        p->errorf(name_token.pos, "main is a reserved word for the entry point function of the program")
    }

    for other in scope {
        if other.name == name {
            p->errorf(
                name_token.pos, "redeclaration of '{}' found in {}:{}:{}",
                name, other.filename, other.line, other.column,
            )
        }
    }

    append(scope, Entity{
        address = address,
        is_global = is_global,
        name = name,
        pos = name_token.pos,
        token = name_token,
        variant = ec,
    })
}

declare_func :: proc(p: ^Parser) {
    name_token := expect(p, .Word)
    name := name_token.text
    f := p.curr_function
    ef := Entity_Function{}
    is_global := f.is_global
    address := is_global ? gen_global_address() : gen_local_address(f)
    scope := &p.scopes[len(p.scopes) - 1]
    parse_function_head(p, &ef)
    is_main := false

    if name == "main" {
        gen.main_func_address = address
        is_main = true
    }

    for &other in scope {
        if other.name == name {
            if is_main {
                p->errorf(
                    name_token.pos, "redeclared main in {}:{}:{}",
                    other.filename, other.line, other.column,
                )
            }

            #partial switch &v in other.variant {
                case Entity_Function: {
                    if v.has_any_input || ef.has_any_input {
                        err_token := v.has_any_input ? other.token : name_token
                        p->errorf(err_token.pos, "a function with 'any' input exists and it can't be polymorphic")
                    }

                    if v.is_parapoly || ef.is_parapoly {
                        err_token := v.is_parapoly ? other.token : name_token
                        p->errorf(err_token.pos, "parapoly functions can't be polymorphic")
                    }

                    v.is_polymorphic = true
                    ef.is_polymorphic = true
                }
                case: p->errorf(
                    name_token.pos, "{} redeclared at {}:{}:{}",
                    other.filename, other.line, other.column,
                )
            }
        }
    }

    append(scope, Entity{
        address = address,
        is_global = is_global,
        name = name,
        pos = name_token.pos,
        token = name_token,
        variant = ef,
    })
}

parse_function :: proc(p: ^Parser, name: string, e: ^Entity) {
    ef := e.variant.(Entity_Function)
    push_function(p, name, e)
    f := p.curr_function

    gen_function_declaration(f)
    gen_function(f, .Head)

    for param in ef.inputs { p.tstack->push(param.kind) }
    body_loop: for { if !parse_token(p, next(p)) { break body_loop } }

    if len(p.tstack.v) != len(ef.outputs) {
        p->errorf(
            e.pos, "mismatched outputs in function {}\n\tExpected: {},\tHave: {}",
            e.name, ef.outputs, p.tstack.v,
        )
    }

    gen_function(f, .Tail)
    pop_function(p)

    p.tstack->clear()
}

parse_token :: proc(p: ^Parser, token: Token) -> bool {
    f := p.curr_function

    switch token.kind {
    case .EOF, .Invalid, .Fn, .Using, .Dash_Dash_Dash:
        p->errorf(
            token.pos, "invalid token as function body {}",
            token_to_string(token),
        )
    case .Semicolon: return false

    case .Const: declare_const(p)

    case .Word:
        if token.text == "println" || token.text == "print" {
            t := p.tstack->pop()
            gen_literal_c(f, "{}({}_t);", token.text, type_to_cname(t))
            return true
        }
        result := find_entity(p, token)

        switch v in result.variant {
        case Entity_Binding:
            gen_push_binding(f, result.address)
            p.tstack->push(v.kind)
        case Entity_Constant:
            switch v2 in v.value {
            case bool: gen_push_bool(f, v2 ? "SKTRUE" : "SKFALSE")
            case f64: gen_push_float(f, v2)
            case int: gen_push_int(f, v2)
            case string: gen_push_string(f, v2)
            case u64: gen_push_uint(f, v2)
            }
            p.tstack->push(v.kind)
        case Entity_C_Function: // TODO: Handle
        case Entity_Function:
            parapoly_table := make(map[string]Type_Kind)
            defer delete(parapoly_table)

            #reverse for input in v.inputs {
                t := p.tstack->pop()

                switch {
                case input.kind == .Parapoly:
                    v, ok := parapoly_table[input.name]

                    if !ok {
                        parapoly_table[input.name] = t
                        v = t
                    }

                    if t != v {
                        p->errorf(
                            token.pos, "parapoly of name '{}' means '{}' in this declaration, got '{}'",
                            input.name, type_readable_table[v], type_readable_table[t],
                        )
                    }
                case input.kind != t:
                    p->errorf(
                        token.pos,
                        "input mismatch in function {}\n\tExpected: {},\tHave: {}",
                        token.text, input, t,
                    )
                }
            }

            for output in v.outputs {
                if output.kind == .Parapoly {
                    v, ok := parapoly_table[output.name]

                    if !ok {
                        p->errorf(token.pos, "parapoly of the name {} not defined in inputs", output.name)
                    }

                    p.tstack->push(v)
                } else {
                    p.tstack->push(output.kind)
                }
            }

            gen_function_call(f, result.address)
        case Entity_Variable: // TODO: Handle
        }

    case .Let:
        scope := push_scope(p)
        words := make([dynamic]Token, context.temp_allocator)
        defer delete(words)
        gen_code_block(f, .start)

        for !allow(p, .In) {
            token := expect(p, .Word)
            append(&words, token)
        }

        #reverse for word in words {
            t := p.tstack->pop()
            address := gen_local_address(f)
            append(scope, Entity{
                address = address,
                pos = word.pos,
                name = word.text,
                variant = Entity_Binding{kind = t},
            })
            gen_binding(f, address)
        }

    case .In:
        unimplemented()

    case .End:
        pop_scope(p)
        gen_code_block(f, .end)

    case .If:

    case .Then:

    case .Fi:

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
        gen_push_bool(f, "SKFALSE")
        p.tstack->push(.Bool)

    case .Float_Literal:
        gen_push_float(f, strconv.atof(token.text))
        p.tstack->push(.Float)

    case .Hex_Literal:
        unimplemented()

    case .Integer_Literal:
        gen_push_int(f, strconv.atoi(token.text))
        p.tstack->push(.Int)

    case .Octal_Literal:
        unimplemented()

    case .String_Literal:
        gen_push_string(f, token.text)
        p.tstack->push(.String)

    case .True_Literal:
        gen_push_bool(f, "SKTRUE")
        p.tstack->push(.Bool)

    case .Uint_Literal:
        val, _ := strconv.parse_u64(token.text)
        gen_push_uint(f, val)
        p.tstack->push(.Uint)

    case .Type_Literal: unimplemented()

    case .Add:
        t := p.tstack->pop()
        p.tstack->pop()
        gen_add(f, t)
        p.tstack->push(t)

    case .Divide:
        t := p.tstack->pop()
        p.tstack->pop()
        gen_divide(f, t)
        p.tstack->push(t)

    case .Modulo:
        t := p.tstack->pop()
        p.tstack->pop()
        gen_modulo(f, t)
        p.tstack->push(t)

    case .Multiply:
        t := p.tstack->pop()
        p.tstack->pop()
        gen_multiply(f, t)
        p.tstack->push(t)

    case .Substract:
        t := p.tstack->pop()
        p.tstack->pop()
        gen_substract(f, t)
        p.tstack->push(t)

    case .Equal:
        t := p.tstack->pop()
        p.tstack->pop()
        gen_equal(f, t)
        p.tstack->push(.Bool)

    case .Greater_Equal:
        t := p.tstack->pop()
        p.tstack->pop()
        gen_greater_equal(f, t)
        p.tstack->push(.Bool)

    case .Greater_Than:
        t := p.tstack->pop()
        p.tstack->pop()
        gen_greater_than(f, t)
        p.tstack->push(.Bool)

    case .Less_Equal:
        t := p.tstack->pop()
        p.tstack->pop()
        gen_less_equal(f, t)
        p.tstack->push(.Bool)

    case .Less_Than:
        t := p.tstack->pop()
        p.tstack->pop()
        gen_less_than(f, t)
        p.tstack->push(.Bool)

    case .Not_Equal:
        t := p.tstack->pop()
        p.tstack->pop()
        gen_not_equal(f, t)
        p.tstack->push(.Bool)

    }

    return true
}
