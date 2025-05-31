package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strconv"
import "core:strings"

Constant_Value :: union { bool, f64, int, string, u64 }

Arity :: distinct [dynamic]Type

Entity_Binding :: struct {
    kind: Type_Kind,
}

Entity_Constant :: struct {
    kind: Type_Kind,
    value: Constant_Value,
}

Entity_Function :: struct {
    inputs:  Arity,
    outputs: Arity,

    is_builtin:   bool,

    is_foreign:   bool,
    foreign_name: string,

    is_inline:     bool,
    inline_tokens: []Token,

    has_any_input:  bool,
    is_parapoly:    bool,
    is_polymorphic: bool,
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
    token:     Token,

    variant: Entity_Variant,
}

Entities :: distinct [dynamic]Entity

Function :: struct {
    using pos: Position,
    address:   uint,
    name:      string,
    entities:  ^Entities,
    local_ip:  uint,

    code:      strings.Builder,
    indent:    int,
    parent:    ^Function,
    is_global: bool,
}

Scope_Kind :: enum {
    Global, Function,
    If_Inline, If, If_Else,
}

Scope :: struct {
    kind:  Scope_Kind,
    token: Token,
    parent: ^Scope,

    entities:      Entities,
    tstack_copies: [dynamic][]Type_Kind,

    validation_at_end: enum {
        Skip,
        Stack_Is_Unchanged,
        Stack_Match_Between,
    },
}

Parser :: struct {
    curr_function: ^Function,
    curr_scope:    ^Scope,
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
    os.exit(1)
}

default_errorf :: proc(
    p: ^Parser, pos: Position, format: string,
    args: ..any, loc := #caller_location,
) -> ! {
    fmt.eprintf("%s(%d:%d): ", pos.filename, pos.line, pos.column)
    fmt.eprintf(format, ..args)
    fmt.eprintln()
    os.exit(1)
}

gscope: ^Scope

add_global_bool_constant :: proc(p: ^Parser, name: string, value: bool) {
    append(&gscope.entities, Entity{
        is_global = true,
        name = name,
        variant = Entity_Constant{
            kind = .Bool,
            value = value,
        },
    })
}

add_global_string_constant :: proc(p: ^Parser, name: string, value: string) {
    append(&gscope.entities, Entity{
        is_global = true,
        name = name,
        variant = Entity_Constant{
            kind = .String,
            value = value,
        },
    })
}

init_everything :: proc(p: ^Parser) {
    gscope = push_function(p, "", nil)

    // Add compiler defined constants
    add_global_bool_constant(p, "OS_DARWIN", ODIN_OS == .Darwin)
    add_global_bool_constant(p, "OS_LINUX", ODIN_OS == .Linux)
    add_global_bool_constant(p, "OS_WINDOWS", ODIN_OS == .Windows)
    add_global_bool_constant(p, "SK_DEBUG", debug_switch_enabled)

    add_global_string_constant(p, "SK_VERSION", COMPILER_VERSION)
}

parse :: proc() {
    p := &Parser{}
    init_type_stack(&p.tstack)
    init_reference_stack(&p.rstack)
    init_generator()

    if p.errorf == nil {
        p.errorf = default_errorf
    }

    init_everything(p)

    for source in source_files {
        tokenizer_init(&p.tokenizer, source)
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
                case .Builtin: {
                    if !token.internal {
                        p->errorf(token.pos, "'builtin' keyword cannot be used outside of internal compiler files.")
                    }

                    if allow(p, .Fn) {
                        declare_func(p, .Builtin)
                        expect(p, .Dash_Dash_Dash)
                    } else if allow(p, .Const) {
                        name_token := expect(p, .Word)

                        found := false
                        for &other in gscope.entities {
                            if other.name == name_token.text {
                                found = true
                                other.pos = name_token.pos
                                other.token = name_token
                                break
                            }
                        }

                        if !found {
                            p->errorf(
                                name_token.pos,
                                "compiler defined constant {} missing", name_token.text,
                            )
                        }

                        for { if next(p).kind == .Semicolon { break } }
                    }
                }
                case .Fn: {
                    declare_func(p)
                    scope_level := 1

                    body_loop: for {
                        token := next(p)

                        #partial switch token.kind {
                            case .Const: scope_level += 1
                            case .Fn: scope_level += 1
                            case .EOF: p->errorf(token.pos, "unexpected end of file")
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

    gen_bootstrap()

    for source in source_files {
        tokenizer_init(&p.tokenizer, source)
        next(p)

        parsing_loop: for {
            token := next(p)

            #partial switch token.kind {
                case .EOF: break parsing_loop
                case .Builtin: {
                    skip_to_end: for {
                        if next(p).kind == .Dash_Dash_Dash {
                            break skip_to_end
                        }
                    }
                }
                case .Fn: {
                    name_token := expect(p, .Word)
                    parsing_entity: ^Entity

                    // Searching the function by its token
                    for &other in gscope.entities {
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

                    if allow(p, .Paren_Left) {
                        skip_to_body: for {
                            if next(p).kind == .Paren_Right {
                                break skip_to_body
                            }
                        }
                    }

                    parse_function(p, name_token.text, parsing_entity)
                }
            }
        }
    }

    pop_function(p)

    assert(p.curr_function == nil && p.curr_scope == nil)

    gen_compilation_unit()

    delete(p.rstack.v)
    delete(p.tstack.v)
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
    possible_matches := make(Entities, context.temp_allocator)
    name := token.text
    test_scope := p.curr_scope
    found := false

    for !found && test_scope != nil {
        for check in test_scope.entities {
            if check.name == name {
                append(&possible_matches, check)
                found = true
            }
        }

        if !found { test_scope = test_scope.parent }
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
        Match_Stats :: struct { entity: Entity, exact_number_inputs: bool, }
        matches := make([dynamic]Match_Stats, 0, 1, context.temp_allocator)

        for other in possible_matches {
            test := other.variant.(Entity_Function)

            if len(p.tstack.v) >= len(test.inputs) {
                stack_copy := slice.clone(p.tstack.v[:])
                defer delete(stack_copy)
                sim_test_stack := stack_copy[:len(test.inputs)]
                func_test_stack := make([dynamic]Type_Kind, context.temp_allocator)
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

        report_posible_matches :: proc(possible_matches: []Entity) -> string {
            if len(possible_matches) == 0 {
                return ""
            }
            builder := strings.builder_make(context.temp_allocator)
            strings.write_string(&builder, "\nPossible matches:\n")

            for e in possible_matches {
                if ef, ok := e.variant.(Entity_Function); ok {
                    fmt.sbprintf(&builder, "\t{0} (", e.name)
                    for input in ef.inputs { fmt.sbprintf(&builder, "{} ", type_readable_table[input.kind]) }
                    if len(ef.outputs) > 0 { fmt.sbprint(&builder, "--- ") }
                    for output, index in ef.outputs {
                        if index == len(ef.outputs) - 1 {
                            fmt.sbprintf(&builder, "{})", type_readable_table[output.kind])
                        } else {
                            fmt.sbprintf(&builder, "{} ", type_readable_table[output.kind])
                        }
                    }
                    fmt.sbprint(&builder, "\n")
                }
            }

            return strings.to_string(builder)
        }

        // Unfortunately we couldn't find a reliable result, so we error out.
        p->errorf(
            token.pos,
            "unable to find matching function of name '{}' with stack {}{}",
            token.text,
            pretty_print_stack(&p.tstack),
            report_posible_matches(possible_matches[:]),
        )
    }

    return Entity{}
}

push_function :: proc(p: ^Parser, name: string, ent: ^Entity) -> ^Scope {
    scope := push_scope(p, ent != nil ? ent.token : Token{})
    p.curr_function = new_clone(Function{
        code      = strings.builder_make(context.temp_allocator),
        entities  = &scope.entities,
        name      = name,
        is_global = name == "",
        parent    = p.curr_function,
    })

    if ent != nil {
        p.curr_function.address = ent.address
        p.curr_function.pos = ent.pos
    }

    scope.kind = .Function
    return p.curr_scope
}

pop_function :: proc(p: ^Parser) {
    old_function := p.curr_function
    p.curr_function = old_function.parent
    pop_scope(p)
    free(old_function)
}

push_scope :: proc(p: ^Parser, token: Token) -> ^Scope {
    p.curr_scope = new_clone(Scope{
        token = token,
        entities = make(Entities, context.temp_allocator),
        parent = p.curr_scope,
    })
    return p.curr_scope
}

pop_scope :: proc(p: ^Parser) {
    switch p.curr_scope.validation_at_end {
    case .Skip:
        // Do nothing

    case .Stack_Is_Unchanged:
        // The stack hasn't changed in length and types. It only supports one stack copy
        stack_copies := &p.curr_scope.tstack_copies

        if len(stack_copies) != 1 || !slice.equal(stack_copies[0], p.tstack.v[:]) {
            p->errorf(
                p.curr_scope.token,
                "stack changes not allowed on this scope block",
            )
        }

    case .Stack_Match_Between:
        // The stack has to have the same result between its branching values
        stack_copies := &p.curr_scope.tstack_copies

        for x in 0..<len(stack_copies) - 1 {
            if !slice.equal(stack_copies[x], stack_copies[x + 1]) {
                p->errorf(
                    p.curr_scope.token,
                    "different stack effects between scopes not allowed",
                )
            }
        }
    }

    for item in p.curr_scope.tstack_copies {
        delete(item)
    }

    delete(p.curr_scope.entities)
    delete(p.curr_scope.tstack_copies)
    old_scope := p.curr_scope
    p.curr_scope = old_scope.parent
    free(old_scope)
}

create_stack_snapshot :: proc(p: ^Parser, scope: ^Scope = nil) {
    s := scope
    if s == nil { s = p.curr_scope }
    append(&s.tstack_copies, slice.clone(p.tstack.v[:]))
}

refresh_stack_snapshot :: proc(p: ^Parser, scope: ^Scope = nil) {
    s := scope
    if s == nil { s = p.curr_scope }
    delete(pop(&s.tstack_copies))
    create_stack_snapshot(p, s)
}

parse_function_head :: proc(p: ^Parser, ef: ^Entity_Function) {
    if allow(p, .Paren_Left) {
        if !allow(p, .Paren_Right) {
            arity := &ef.inputs
            outputs := false

            arity_loop: for {
                token := next(p)

                #partial switch token.kind {
                    case .Paren_Right: break arity_loop
                    case .Dash_Dash_Dash: arity = &ef.outputs; outputs = true
                    case .Word: {
                        ef.is_parapoly = true
                        append(arity, Type{.Parapoly, token.text})
                    }
                    case .Type_Literal: {
                        t := type_string_to_kind(token.text)
                        if t == .Any {
                            ef.has_any_input = true

                            if outputs {
                                p->errorf(token.pos, "functions can't have 'Any' as outputs")
                            }
                        }
                        append(arity, Type{t, token.text})
                    }
                    case: p->errorf(
                        token.pos, "unexpected token %s", token_to_string(token),
                    )
                }
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
    entities := &p.curr_scope.entities
    inferred_type: Type_Kind
    temp_value_stack := make([dynamic]Constant_Value, context.temp_allocator)
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
                // This is some dirty stuff but we have to manage basic operations internally
                // Because +, -, /, *, % are not internal functionality, we need to do this
                // within the compiler.
                switch token.text {
                case "+", "-", "%", "/", "*":
                    v2 := pop(&temp_value_stack)
                    v1 := pop(&temp_value_stack)
                    switch token.text {
                    case "+":
                        #partial switch inferred_type {
                            case .Float: append(&temp_value_stack, v1.(f64) + v2.(f64))
                            case .Int: append(&temp_value_stack, v1.(int) + v2.(int))
                            case .Uint: append(&temp_value_stack, v1.(u64) + v2.(u64))
                        }
                    case "/":
                        #partial switch inferred_type {
                            case .Float: append(&temp_value_stack, v1.(f64) / v2.(f64))
                            case .Int: append(&temp_value_stack, v1.(int) / v2.(int))
                            case .Uint: append(&temp_value_stack, v1.(u64) / v2.(u64))
                        }
                    case "%":
                        #partial switch inferred_type {
                            case .Float: p->errorf(
                                token.pos, "Opertor '%' only allowed with integers",
                            )
                            case .Int: append(&temp_value_stack, v1.(int) % v2.(int))
                            case .Uint: append(&temp_value_stack, v1.(u64) % v2.(u64))
                        }
                    case "*":
                        #partial switch inferred_type {
                            case .Float: append(&temp_value_stack, v1.(f64) * v2.(f64))
                            case .Int: append(&temp_value_stack, v1.(int) * v2.(int))
                            case .Uint: append(&temp_value_stack, v1.(u64) * v2.(u64))
                        }
                    case "-":
                        #partial switch inferred_type {
                            case .Float: append(&temp_value_stack, v1.(f64) - v2.(f64))
                            case .Int: append(&temp_value_stack, v1.(int) - v2.(int))
                            case .Uint: append(&temp_value_stack, v1.(u64) - v2.(u64))
                        }
                    }
                case :
                    entity := find_entity(p, token)

                    #partial switch v in entity.variant {
                        case Entity_Constant: {
                            if inferred_type != .Invalid && inferred_type != v.kind {
                                p->errorf(
                                    token.pos,
                                    "word '{}' of type '{}' cannot be used in expected type of {}",
                                    entity.name, v.kind, inferred_type,
                                )
                            }

                            inferred_type = v.kind

                            #partial switch v.kind {
                                case .Float, .Int, .Uint: append(&temp_value_stack, v.value)
                                case: {
                                    ec.value = v.value
                                    expect(p, .Semicolon)
                                    break body_loop
                                }
                            }
                        }
                        case: p->errorf(token.pos, "'{}' is not a compile-time known constant")
                    }
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

    for other in entities {
        if other.name == name {
            p->errorf(
                name_token.pos, "redeclaration of '{}' found in {}:{}:{}",
                name, other.filename, other.line, other.column,
            )
        }
    }

    append(entities, Entity{
        is_global = is_global,
        name = name,
        pos = name_token.pos,
        token = name_token,
        variant = ec,
    })
}

declare_func :: proc(p: ^Parser, kind: enum { Default, Builtin, Foreign } = .Default) {
    name_token := expect(p, .Word)
    name := name_token.text
    f := p.curr_function
    ef := Entity_Function{
        inputs = make(Arity, context.temp_allocator),
        outputs = make(Arity, context.temp_allocator),

        is_builtin = kind == .Builtin,
        is_foreign = kind == .Foreign,
        //is_inline = start_token.kind == .Inline_Fn,
    }
    is_global := f.is_global
    address := is_global ? gen_global_address() : gen_local_address(f)
    entities := &p.curr_scope.entities
    parse_function_head(p, &ef)
    is_main := false

    if name == "main" {
        gen.main_func_address = address
        is_main = true
    }

    for &other in entities {
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

    append(entities, Entity{
        address = address,
        is_global = is_global,
        name = name,
        pos = name_token.pos,
        token = name_token,
        variant = ef,
    })
}

call_builtin_func :: proc(p: ^Parser, e: Entity) {
    f := p.curr_function
    ef := e.variant.(Entity_Function)

    switch e.name {
    case "len":
        p.tstack->pop()
        gen_string_length(f)
        p.tstack->push(.Int)

    case "+", "-", "%", "*", "/":
        rhs := p.tstack->pop()
        lhs := p.tstack->pop()
        res := ef.outputs[0].kind
        gen_basic_arithmetic(f, lhs, rhs, res, e.name)
        p.tstack->push(res)
    }
}

call_function :: proc(p: ^Parser, entity: Entity) {
    f := p.curr_function
    ef := entity.variant.(Entity_Function)
    token := p.prev_token
    parapoly_table := make(map[string]Type_Kind, context.temp_allocator)
    defer delete(parapoly_table)

    #reverse for input in ef.inputs {
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
                    token.pos,
                    "parapoly of name '{}' means '{}' in this declaration, got '{}'",
                    input.name, type_readable_table[v], type_readable_table[t],
                )
            }
        case input.kind != t && input.kind != .Any:
            p->errorf(
                token.pos,
                "input mismatch in function {}\n\tExpected: {},\tHave: {}",
                token.text, input, t,
            )
        }
    }

    for output in ef.outputs {
        if output.kind == .Parapoly {
            v, ok := parapoly_table[output.name]

            if !ok {
                p->errorf(
                    token.pos,
                    "parapoly of the name {} not defined in inputs", output.name,
                )
            }

            p.tstack->push(v)
        } else {
            p.tstack->push(output.kind)
        }
    }

    gen_function_call(f, entity.address)
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
    case .Builtin, .Foreign: unimplemented()

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
        case Entity_Function:
            switch {
            case v.is_builtin: call_builtin_func(p, result)
            case: call_function(p, result)
            }
        case Entity_Variable: // TODO: Handle
        }

    case .Let:
        scope := push_scope(p, token)
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
            append(&scope.entities, Entity{
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

    case .Case: unimplemented()

    case .If:
        scope := push_scope(p, token)
        scope.validation_at_end = .Stack_Is_Unchanged
        scope.kind = .If

    case .Then:
        t := p.tstack->pop()
        if t != .Bool { p->errorf(token.pos, "Non-boolean condition in 'if' statement") }

        if p.curr_scope.kind == .If {
            create_stack_snapshot(p)
            p.tstack->save()
            gen_if_statement(f, .s_if)
        } else {
            // This has to be an inline (ternary) if test, we don't need to
            // start the block with 'if', and we support only one function for the body.
            scope := push_scope(p, token)
            scope.kind = .If_Inline
            scope.validation_at_end = .Stack_Is_Unchanged
            p.tstack->save()
            gen_if_statement(f, .s_if)

            parse_token(p, next(p))
            create_stack_snapshot(p)
            p.tstack->reset()

            if allow(p, .Else) {
                scope.validation_at_end = .Stack_Match_Between
                gen_if_statement(f, .s_else)
                parse_token(p, next(p))
                create_stack_snapshot(p)
            }

            allow(p, .Fi)
            pop_scope(p)
            gen_if_statement(f, .fi)
        }

    case .Else:
        p.curr_scope.kind = .If_Else
        p.curr_scope.validation_at_end = .Stack_Match_Between
        refresh_stack_snapshot(p)
        p.tstack->reset()
        gen_if_statement(f, .s_else)

    case .Fi:
        close_if_statements: for {
            switch {
            case p.curr_scope.kind == .If:
                pop_scope(p)
                p.tstack->reset()
            case p.curr_scope.kind == .If_Else:
                create_stack_snapshot(p)
                pop_scope(p)
            case: break close_if_statements
            }

            gen_if_statement(f, .fi)
        }

    case .Leave:
        gen_literal_c(f, "return;")

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
