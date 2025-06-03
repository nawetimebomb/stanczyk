package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strconv"
import "core:strings"

Constant_Value :: union { bool, f64, int, string }

Arity :: distinct [dynamic]Type

Entity_Binding :: struct {
    kind: Type_Kind,
    index: int,
}

Entity_Constant :: struct {
    kind: Type_Kind,
    value: Constant_Value,
}

Entity_Function :: struct {
    inputs:  Arity,
    outputs: Arity,

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

    is_builtin:   bool,
    is_foreign:   bool,
    foreign_name: string,

    variant: Entity_Variant,
}

Code :: distinct [dynamic]Bytecode

Function :: struct {
    entity: ^Entity,
    parent: ^Function,

    called:   bool,
    local_ip: uint,

    code:     Code,
    codestr:  strings.Builder,
    indent:   int,
    stack:    Stack,
}

Scope_Kind :: enum {
    Invalid,
    Function,
    Global,
    If,
    If_Else,
    If_Inline,
    Let,
    Do,
    For_Range,
}

Entities :: distinct [dynamic]Entity

Scope :: struct {
    kind:  Scope_Kind,
    token: Token,
    parent: ^Scope,
    level: int,

    start_op: ^Bytecode,

    entities:      Entities,
    stack_copies:  [dynamic][]Type_Kind,

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

    tstack: Type_Stack,

    fatalf: proc(p: ^Parser, pos: Position, format: string,
                 args: ..any, loc := #caller_location) -> !,
}

functions := make([dynamic]Function)
strings_count := 0
strings_table := map[string]int{}

global_fatalf :: proc(format: string, args: ..any, loc := #caller_location) {
    fmt.eprintf("compilation error: ")
    fmt.eprintf(format, ..args)
    fmt.eprintln()
    os.exit(1)
}

default_fatalf :: proc(
    p: ^Parser, pos: Position, format: string,
    args: ..any, loc := #caller_location,
) -> ! {
    fmt.eprintf("%s(%d:%d): ", pos.filename, pos.line, pos.column)
    fmt.eprintf(format, ..args)
    fmt.eprintln()
    os.exit(1)
}

gscope: ^Scope

add_to_string_table :: proc(v: string) -> int {
    id, ok := strings_table[v]

    if !ok {
        id = strings_count
        strings_table[v] = id
        strings_count += 1
    }

    return id
}

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
            value = add_to_string_table(value),
        },
    })
}

compile :: proc() {
    p := &Parser{}
    init_type_stack(&p.tstack)
    init_generator()

    if p.fatalf == nil {
        p.fatalf = default_fatalf
    }

    init_everything(p)

    for source in source_files {
        tokenizer_init(&p.tokenizer, source)
        next(p)

        loop: for {
            token := next(p)

            #partial switch token.kind {
                case .Using: {
                    for {
                        token := next(p)
                        if token.kind == .Semicolon { break }

                        if token.kind == .Word {
                            dir := "base"
                            filename := token.text

                            if strings.contains(filename, ".") {
                                dir, _, filename = strings.partition(filename, ".")
                            }

                            load_file(fmt.tprintf("{}.sk", filename), false, fmt.tprintf("{}/{}", compiler_dir, dir))
                        }
                    }
                }
                case .Const: {
                    declare_const(p)
                }
                case .Foreign: {
                    if allow(p, .Fn) {
                        declare_func(p, .Foreign)
                        expect(p, .Dash_Dash_Dash)
                    } else {
                        p->fatalf(
                            token.pos, "unimplemented functionality",
                        )
                    }
                }
                case .Builtin: {
                    if !token.internal {
                        p->fatalf(token.pos, "'builtin' keyword cannot be used outside of internal compiler files.")
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
                            p->fatalf(
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
                            case .EOF: p->fatalf(token.pos, "unexpected end of file")
                            case .Semicolon: {
                                scope_level -= 1
                                if scope_level == 0 { break body_loop }
                            }
                        }
                    }
                }
                case .EOF: break loop
                case: p->fatalf(
                    token.pos, "unexpected token of type %s", token_to_string(token),
                )
            }
        }
    }

    for source in source_files {
        tokenizer_init(&p.tokenizer, source)
        next(p)

        parsing_loop: for {
            token := next(p)

            #partial switch token.kind {
                case .EOF: break parsing_loop
                case .Builtin, .Foreign: {
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
                        p->fatalf(
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

                    parse_function(p, parsing_entity)
                }
            }
        }
    }

    gen_program()
    deinit_everything(p)
}

init_everything :: proc(p: ^Parser) {
    gscope = push_scope(p, Token{}, .Global)

    // Add compiler defined constants
    add_global_bool_constant(p, "OS_DARWIN", ODIN_OS == .Darwin)
    add_global_bool_constant(p, "OS_LINUX", ODIN_OS == .Linux)
    add_global_bool_constant(p, "OS_WINDOWS", ODIN_OS == .Windows)
    add_global_bool_constant(p, "SK_DEBUG", debug_switch_enabled)

    add_global_string_constant(p, "SK_VERSION", COMPILER_VERSION)
}

deinit_everything :: proc(p: ^Parser) {
    assert(p.curr_scope.parent == nil)
    delete_scope(p.curr_scope)
    assert(p.curr_function == nil)
    delete(p.tstack.v)

    for &f in functions {
        f.stack->free()
        delete(f.code)
    }

    delete(strings_table)
}

emit :: proc(f: ^Function, token: Token, v: Bytecode_Variant) -> ^Bytecode {
    append(&f.code, Bytecode{
        address = get_local_address(f),
        pos = token.pos,
        variant = v,
    })
    return &f.code[len(f.code) - 1]
}

next :: proc(p: ^Parser) -> Token {
    token, err := get_next_token(&p.tokenizer)
    if err != nil && token.kind != .EOF {
        p->fatalf(token.pos, "found invalid token: %v", err)
    }
    p.prev_token, p.curr_token = p.curr_token, token
    return p.prev_token
}

expect :: proc(p: ^Parser, kind: Token_Kind) -> Token {
    token := next(p)

    if token.kind != kind {
        p->fatalf(
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
        p->fatalf(token.pos, "undefined word '%s'", name)
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
                slice.reverse(stack_copy)
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
                    for input, index in ef.inputs {
                        if len(ef.outputs) == 0 && index == len(ef.inputs) - 1 {
                            fmt.sbprintf(&builder, "{})", type_readable_table[input.kind])
                        } else {
                            fmt.sbprintf(&builder, "{} ", type_readable_table[input.kind])
                        }
                    }
                    if len(ef.outputs) > 0 {
                        fmt.sbprint(&builder, "--- ")
                        for output, index in ef.outputs {
                            if index == len(ef.outputs) - 1 {
                                fmt.sbprintf(&builder, "{})", type_readable_table[output.kind])
                            } else {
                                fmt.sbprintf(&builder, "{} ", type_readable_table[output.kind])
                            }
                        }
                    }
                    fmt.sbprint(&builder, "\n")
                }
            }

            return strings.to_string(builder)
        }

        // Unfortunately we couldn't find a reliable result, so we error out.
        p->fatalf(
            token.pos,
            "unable to find matching function of name '{}' with stack {}{}",
            token.text,
            pretty_print_stack(&p.tstack),
            report_posible_matches(possible_matches[:]),
        )
    }

    return Entity{}
}

push_function :: proc(p: ^Parser, entity: ^Entity) -> ^Scope {
    // TODO: This only support global functions, which I think it's fine, but if sometime
    // we want to support functions inside another function scope, we need to allow it here.
    for &f in functions {
        if f.entity.token == entity.token {
            p.curr_function = &f
            break
        }
    }

    fmt.assertf(p.curr_function != nil, "missing {}", entity.name)

    return push_scope(p, entity.token, .Function)
}

pop_function :: proc(p: ^Parser) {
    assert(p.curr_function != nil)
    pop_scope(p)
    p.curr_function = p.curr_function.parent
}

push_scope :: proc(p: ^Parser, t: Token, k: Scope_Kind) -> ^Scope {
    p.curr_scope = new_clone(Scope{
        token = t,
        entities = make(Entities, context.temp_allocator),
        parent = p.curr_scope,
        level = p.curr_scope == nil ? 0 : p.curr_scope.level + 1,
        kind = k,
    })
    return p.curr_scope
}

pop_scope :: proc(p: ^Parser) {
    assert(p.curr_scope != nil)
    assert(p.curr_function != nil)

    switch p.curr_scope.validation_at_end {
    case .Skip:
        // Do nothing

    case .Stack_Is_Unchanged:
        // The stack hasn't changed in length and types. It only supports one stack copy
        stack_copies := &p.curr_scope.stack_copies
        assert(len(stack_copies) > 0)

        if len(stack_copies) != 1 || !slice.equal(stack_copies[0], p.tstack.v[:]) {
            p->fatalf(
                p.curr_scope.token,
                "stack changes not allowed on this scope block\n\tBefore: {}\n\tAfter: {}",
                stack_copies[0], p.tstack.v,
            )
        }

    case .Stack_Match_Between:
        // The stack has to have the same result between its branching values
        stack_copies := &p.curr_scope.stack_copies

        for x in 0..<len(stack_copies) - 1 {
            if !slice.equal(stack_copies[x], stack_copies[x + 1]) {
                p->fatalf(
                    p.curr_scope.token,
                    "different stack effects between scopes not allowed",
                )
            }
        }
    }

    for item in p.curr_scope.stack_copies {
        delete(item)
    }

    // Realign bindings after the scope is closed
    binds_count_in_scope := 0

    for e in p.curr_scope.entities {
        if _, ok := e.variant.(Entity_Binding); ok {
            binds_count_in_scope += 1
        }
    }

    update_scope := p.curr_scope.parent

    for update_scope != nil {
        for &e in update_scope.entities {
            #partial switch &v in e.variant {
                case Entity_Binding: v.index -= binds_count_in_scope
            }
        }

        update_scope = update_scope.parent
    }

    old_scope := p.curr_scope
    p.curr_scope = old_scope.parent
    delete_scope(old_scope)
}

delete_scope :: proc(s: ^Scope) {
    for &e in s.entities {
        #partial switch v in e.variant {
            case Entity_Function: {
                delete(v.inputs)
                delete(v.outputs)
            }
        }
    }

    delete(s.entities)
    delete(s.stack_copies)
    free(s)
}

create_stack_snapshot :: proc(p: ^Parser, scope: ^Scope = nil) {
    s := scope
    if s == nil { s = p.curr_scope }
    append(&s.stack_copies, slice.clone(p.tstack.v[:]))
}

refresh_stack_snapshot :: proc(p: ^Parser, scope: ^Scope = nil) {
    s := scope
    if s == nil { s = p.curr_scope }
    delete(pop(&s.stack_copies))
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
                                p->fatalf(token.pos, "functions can't have 'Any' as outputs")
                            }
                        }
                        append(arity, Type{t, token.text})
                    }
                    case: p->fatalf(
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
            case .EOF: p->fatalf(token.pos, "unexpected end of file")
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
                            case .Uint: append(&temp_value_stack, v1.(int) + v2.(int))
                        }
                    case "/":
                        #partial switch inferred_type {
                            case .Float: append(&temp_value_stack, v1.(f64) / v2.(f64))
                            case .Int: append(&temp_value_stack, v1.(int) / v2.(int))
                            case .Uint: append(&temp_value_stack, v1.(int) / v2.(int))
                        }
                    case "%":
                        #partial switch inferred_type {
                            case .Float: p->fatalf(
                                token.pos, "Opertor '%' only allowed with integers",
                            )
                            case .Int: append(&temp_value_stack, v1.(int) % v2.(int))
                            case .Uint: append(&temp_value_stack, v1.(int) % v2.(int))
                        }
                    case "*":
                        #partial switch inferred_type {
                            case .Float: append(&temp_value_stack, v1.(f64) * v2.(f64))
                            case .Int: append(&temp_value_stack, v1.(int) * v2.(int))
                            case .Uint: append(&temp_value_stack, v1.(int) * v2.(int))
                        }
                    case "-":
                        #partial switch inferred_type {
                            case .Float: append(&temp_value_stack, v1.(f64) - v2.(f64))
                            case .Int: append(&temp_value_stack, v1.(int) - v2.(int))
                            case .Uint: append(&temp_value_stack, v1.(int) - v2.(int))
                        }
                    }
                case :
                    entity := find_entity(p, token)

                    #partial switch v in entity.variant {
                        case Entity_Constant: {
                            if inferred_type != .Invalid && inferred_type != v.kind {
                                p->fatalf(
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
                        case: p->fatalf(token.pos, "'{}' is not a compile-time known constant")
                    }
                }
            }
            case .Bool_Literal: {
                ec.value = token.text == "true" ? true : false
                inferred_type = .Bool
                expect(p, .Semicolon)
                break body_loop
            }
            case .Cstring_Literal: unimplemented()
            case .Float_Literal: {
                append(&temp_value_stack, strconv.atof(token.text))
                if inferred_type == .Invalid {
                    inferred_type = .Float
                } else if inferred_type != .Float {
                    p->fatalf(token.pos, "expected type {} in constant", inferred_type)
                }
            }
            case .Integer_Literal: {
                append(&temp_value_stack, strconv.atoi(token.text))
                if inferred_type == .Invalid {
                    inferred_type = .Int
                } else if inferred_type != .Int {
                    p->fatalf(token.pos, "can't mix type of values in constant")
                }
            }
            case .String_Literal: {
                ec.value = token.text
                inferred_type = .String
                expect(p, .Semicolon)
                break body_loop
            }
            case .Uint_Literal: {
                append(&temp_value_stack, strconv.atoi(token.text))
                if inferred_type == .Invalid {
                    inferred_type = .Uint
                } else if inferred_type != .Uint {
                    p->fatalf(token.pos, "can't mix type of values in constant")
                }
            }
        }
    }

    if ec.kind == .Invalid {
        ec.kind = inferred_type
    } else if ec.kind != inferred_type {
        p->fatalf(
            name_token,
            "type declaration of {} doesn't match value type of {} in constant '{}'",
            ec.kind, inferred_type, name,
        )
    }

    if len(temp_value_stack) > 0 {
        if len(temp_value_stack) != 1 {
            p->fatalf(name_token, "values in constant don't compile to a single value")
        }

        ec.value = pop(&temp_value_stack)
    }

    if name == "main" {
        p->fatalf(name_token.pos, "main is a reserved word for the entry point function of the program")
    }

    for other in entities {
        if other.name == name {
            p->fatalf(
                name_token.pos, "redeclaration of '{}' found in {}:{}:{}",
                name, other.filename, other.line, other.column,
            )
        }
    }

    append(entities, Entity{
        name = name,
        pos = name_token.pos,
        token = name_token,
        variant = ec,
    })
}

declare_func :: proc(p: ^Parser, kind: enum { Default, Builtin, Foreign } = .Default) {
    name_token := expect(p, .Word)
    name := name_token.text
    is_foreign := kind == .Foreign
    is_builtin := kind == .Builtin
    foreign_name := name
    address := get_global_address()
    entities := &p.curr_scope.entities
    is_main := false
    ef := Entity_Function{
        inputs = make(Arity),
        outputs = make(Arity),
        //is_inline = start_token.kind == .Inline_Fn,
    }

    if is_foreign {
        if allow(p, .As) {
            foreign_name = name
            name_token = expect(p, .Word)
            name = name_token.text
        }
    }

    parse_function_head(p, &ef)

    if name == "main" {
        gen.main_func_address = address
        is_main = true
    }

    for &other in entities {
        if other.name == name {
            if is_main {
                p->fatalf(
                    name_token.pos, "redeclared main in {}:{}:{}",
                    other.filename, other.line, other.column,
                )
            }

            #partial switch &v in other.variant {
                case Entity_Function: {
                    if v.has_any_input || ef.has_any_input {
                        err_token := v.has_any_input ? other.token : name_token
                        p->fatalf(err_token.pos, "a function with 'any' input exists and it can't be polymorphic")
                    }

                    if v.is_parapoly || ef.is_parapoly {
                        err_token := v.is_parapoly ? other.token : name_token
                        p->fatalf(err_token.pos, "parapoly functions can't be polymorphic")
                    }

                    v.is_polymorphic = true
                    ef.is_polymorphic = true
                }
                case: p->fatalf(
                    name_token.pos, "{} redeclared at {}:{}:{}",
                    other.filename, other.line, other.column,
                )
            }
        }
    }

    append(entities, Entity{
        address = address,
        is_global = true, // functions are only allowed in global scope
        is_builtin = is_builtin,
        is_foreign = is_foreign,
        name = name,
        foreign_name = foreign_name,
        pos = name_token.pos,
        token = name_token,
        variant = ef,
    })

    if !is_builtin && !is_foreign {
        // Builtin functions are compiler-defined, so they don't
        // really create any code, but instead do custom code generation.
        append(&functions, Function{
            entity = &entities[len(entities) - 1],
            called = name == "main",
            local_ip = 0,
            codestr = strings.builder_make(),
        })
    }
}

call_foreign_func :: proc(p: ^Parser, f: ^Function, t: Token, e: Entity) {
    ef := e.variant.(Entity_Function)

    #reverse for input in ef.inputs {
        T := p.tstack->pop()

        if input.kind != T {
            p->fatalf(
                t.pos,
                "input mismatch in function {}\n\tExpected: {},\tHave: {}",
                t.text, input, T,
            )
        }
    }

    for output in ef.outputs {
        p.tstack->push(output.kind)
    }

    emit(f, t, Call_C_Function{
        name = e.foreign_name,
        inputs = len(ef.inputs),
        outputs = len(ef.outputs),
    })
}

call_builtin_func :: proc(p: ^Parser, f: ^Function, t: Token, e: Entity) {
    ef := e.variant.(Entity_Function)

    switch e.name {
    case "len":
        p.tstack->pop()
        // gen_string_length(f)
        p.tstack->push(.Int)

    case "+", "-", "%", "*", "/":
        rhs := p.tstack->pop()
        lhs := p.tstack->pop()
        res := ef.outputs[0].kind
        p.tstack->push(res)
        switch e.name {
        case "+": emit(f, t, Add{})
        case "/": emit(f, t, Divide{})
        case "%": emit(f, t, Modulo{})
        case "*": emit(f, t, Multiply{})
        case "-": emit(f, t, Substract{})
        }
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
                p->fatalf(
                    token.pos,
                    "parapoly of name '{}' means '{}' in this declaration, got '{}'",
                    input.name, type_readable_table[v], type_readable_table[t],
                )
            }
        case input.kind != t && input.kind != .Any:
            p->fatalf(
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
                p->fatalf(
                    token.pos,
                    "parapoly of the name {} not defined in inputs", output.name,
                )
            }

            p.tstack->push(v)
        } else {
            p.tstack->push(output.kind)
        }
    }

    // Mark the function as called.
    for &f in functions {
        if f.entity.token == entity.token { f.called = true }
    }

    emit(f, token, Call_Function{
        address = entity.address,
        name = entity.name,
    })
    // gen_function_call(f, entity.address)
}

parse_function :: proc(p: ^Parser, e: ^Entity) {
    ef := e.variant.(Entity_Function)
    push_function(p, e)
    stack_create(p.curr_function)
    // gen_function(p.curr_function, .Head)
    for param in ef.inputs { p.tstack->push(param.kind) }
    body_loop: for { if !parse_token(p, next(p), p.curr_function) { break body_loop } }
    if len(p.tstack.v) != len(ef.outputs) {
        p->fatalf(
            e.pos, "mismatched outputs in function {}\n\tExpected: {},\tHave: {}",
            e.name, ef.outputs, p.tstack.v,
        )
    }
    pop_function(p)
    p.tstack->clear()
}

parse_token :: proc(p: ^Parser, token: Token, f: ^Function) -> bool {
    switch token.kind {
    case .EOF, .Invalid, .Fn, .Using, .Dash_Dash_Dash, .Builtin, .Foreign:
        p->fatalf(
            token.pos, "invalid token as function body {}",
            token_to_string(token),
        )

    case .Semicolon:
        emit(f, token, Return{})
        return false

    case .Const: declare_const(p)

    case .Word:
        if token.text == "println" || token.text == "print" {
            t := p.tstack->pop()
            emit(f, token, Print{t})
            return true
        }
        result := find_entity(p, token)

        switch v in result.variant {
        case Entity_Binding:
            emit(f, token, Push_Bound{v.index})
            p.tstack->push(v.kind)
        case Entity_Constant:
            #partial switch v.kind {
                case .Bool: emit(f, token, Push_Bool{v.value.(bool)})
                case .Int:  emit(f, token, Push_Int{v.value.(int)})
                case .String: emit(
                    f, token, Push_String{
                        add_to_string_table(v.value.(string)),
                    },
                )
                case .Uint: emit(f, token, Push_Int{v.value.(int)})
            }
            p.tstack->push(v.kind)
        case Entity_Function:
            switch {
            case result.is_builtin: call_builtin_func(p, f, token, result)
            case result.is_foreign: call_foreign_func(p, f, token, result)
            case: call_function(p, result)
            }
        case Entity_Variable: // TODO: Handle
        }

    case .As:
    case .Let:
        scope := push_scope(p, token, .Let)
        words := make([dynamic]Token, context.temp_allocator)
        defer delete(words)

        for !allow(p, .In) {
            token := expect(p, .Word)
            append(&words, token)
        }

        bind_words(p, f, words[:])
        emit(f, token, Let_Bind{len(words)})

    case .In:
        unimplemented()

    case .End:
        if p.curr_scope.kind == .Let {
            binds_count := 0

            for e in p.curr_scope.entities {
                if _, ok := e.variant.(Entity_Binding); ok {
                    binds_count += 1
                }
            }

            emit(f, token, Let_Unbind{binds_count})
        }

        pop_scope(p)

    case .Case: unimplemented()

    case .If:
        t := p.tstack->pop()
        if t != .Bool { p->fatalf(token.pos, "Non-boolean condition in 'if' statement") }

        scope := push_scope(p, token, .If)
        scope.validation_at_end = .Stack_Is_Unchanged
        scope.start_op = emit(f, token, If{})
        create_stack_snapshot(p)
        p.tstack->save()

    case .Else:
        if p.curr_scope.kind != .If {
            p->fatalf(token.pos, "'else' unattached to an 'if' statement")
        }

        p.curr_scope.kind = .If_Else
        p.curr_scope.validation_at_end = .Stack_Match_Between
        refresh_stack_snapshot(p)
        p.tstack->reset()
        b := emit(f, token, Else{p.curr_scope.start_op.address})
        p.curr_scope.start_op = b

    case .Fi:
        should_error := true
        close_if_statements: for {
            switch {
            case p.curr_scope.kind == .If:
                b := emit(f, token, Fi{p.curr_scope.start_op.address})
                should_error = false
                pop_scope(p)
                p.tstack->reset()
            case p.curr_scope.kind == .If_Else:
                b := emit(f, token, Fi{p.curr_scope.start_op.address})
                should_error = false
                create_stack_snapshot(p)
                pop_scope(p)
            case :
                if should_error {
                    p->fatalf(
                        token.pos, "'fi' unattached to an 'if' statement",
                    )
                }
                break close_if_statements
            }
        }

    case .For:
        scope := push_scope(p, token, .Invalid)
        words := make([dynamic]Token, context.temp_allocator)
        defer delete(words)
        append(&words, expect(p, .Word))
        if allow(p, .Word) { append(&words, p.prev_token) }
        expect(p, .In)

        // "for" support multiple types of loop, and in order to figure out what type of
        // loop we're going to be parsing here, we need to know more about the context.
        // Usually the first parameter in the loop will tell us exactly what to do.
        // The first parameter should ALWAYS push a value to the stack, and we're inferring
        // the desired loop with that value pushed into the stack.
        // TODO: Create a mechanism of safety to make sure the parse_token below is actually
        // pushing something to the stack.
        parse_token(p, next(p), f) // Hopefully, something was pushed...

        // T tells us what to do
        T := p.tstack->peek()

        if T == .Int {
            // This is the regular range for loop
            if len(words) != 1 {
                p->fatalf(token.pos, "only one word can be bound in this range 'for' loop")
            }

            // We're doing implicit binding here, that means we take the necessary words
            // out of the stack, but then, this operation also emits a value into the stack
            // (the previously bound value), so we re-add it as part of the emit.
            bind_words(p, f, words[:])
            scope.start_op = emit(f, token, For_Range{})
            p.tstack->push(T)
            scope.kind = .For_Range
            parse_token(p, next(p), f)
            parse_token(p, next(p), f)
            Y := p.tstack->pop()
            if Y != .Bool {
                p->fatalf(token.pos, "Non-boolean condition in 'for' range statement")
            }
            emit(f, expect(p, .Do), Do{
                address = scope.start_op.address,
                use_self = false,
            })
            create_stack_snapshot(p)
            p.tstack->save()
        } else if T == .String {
            // This is a string iteration. We are looking into the string's characters.
            unimplemented()
        } else {
            p->fatalf(token.pos, "we don't know what to do here, yet!")
        }

    case .Do:
        t := p.tstack->pop()
        if t != .Bool { p->fatalf(token.pos, "Non-boolean condition in 'while' statement") }

        scope := push_scope(p, token, .Do)
        scope.validation_at_end = .Stack_Is_Unchanged
        scope.start_op = emit(f, token, Do{ use_self = true })
        create_stack_snapshot(p)
        p.tstack->save()

    case .Loop:
        #partial switch p.curr_scope.kind {
            case .Do: {
                T := p.tstack->pop()
                if T != .Bool {
                    p->fatalf(token.pos, "Non-boolean condition in 'loop' statement")
                }

                b := emit(f, token, Loop{
                    address = p.curr_scope.start_op.address,
                    bindings = 0,
                })
                pop_scope(p)
                p.tstack->reset()
            }
            case .For_Range: {
                T := p.tstack->pop()
                if T != .Int {
                    p->fatalf(token.pos, "Int expected in 'loop' statement")
                }
                b := emit(f, token, Loop{
                    address = p.curr_scope.start_op.address,
                    bindings = 1,
                })
                pop_scope(p)
                p.tstack->reset()
            }
            case : p->fatalf(token.pos, "'loop' unattached to a 'for' or 'do' scope")
        }

    case .Leave:
        emit(f, token, Return{})

    case .Get:
        p.tstack->pop()
        emit(f, token, Get{})
        p.tstack->push(.Int)
    case .Get_Byte:
        p.tstack->pop()
        p.tstack->pop()
        emit(f, token, Get_Byte{})
        p->tstack->push(.Byte)
    case .Set:
        p.tstack->pop()
        p.tstack->pop()
        emit(f, token, Set{})
    case .Set_Byte:
        p.tstack->pop()
        p.tstack->pop()
        emit(f, token, Set_Byte{})

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
        emit(f, token, Push_Byte{token.text[0]})
        p.tstack->push(.Byte)

    case .Bool_Literal:
        emit(f, token, Push_Bool{token.text == "true" ? true : false})
        p.tstack->push(.Bool)

    case .Cstring_Literal:
        emit(f, token, Push_Cstring{add_to_string_table(token.text), len(token.text)})
        p.tstack->push(.String)
        p.tstack->push(.Int)

    case .Float_Literal:
        fmt.assertf(false, "unimplemented for now")
        p.tstack->push(.Float)

    case .Hex_Literal:
        unimplemented()

    case .Integer_Literal:
        emit(f, token, Push_Int{strconv.atoi(token.text)})
        p.tstack->push(.Int)

    case .Octal_Literal:
        unimplemented()

    case .String_Literal:
        emit(f, token, Push_String{add_to_string_table(token.text)})
        p.tstack->push(.String)

    case .Uint_Literal:
        emit(f, token, Push_Int{strconv.atoi(token.text)})
        p.tstack->push(.Uint)

    case .Type_Literal: unimplemented()

    case .Equal:
        t := p.tstack->pop()
        p.tstack->pop()
        emit(f, token, Equal{})
        p.tstack->push(.Bool)

    case .Greater_Equal:
        t := p.tstack->pop()
        p.tstack->pop()
        emit(f, token, Greater_Equal{})
        p.tstack->push(.Bool)

    case .Greater_Than:
        t := p.tstack->pop()
        p.tstack->pop()
        emit(f, token, Greater{})
        p.tstack->push(.Bool)

    case .Less_Equal:
        t := p.tstack->pop()
        p.tstack->pop()
        emit(f, token, Less_Equal{})
        p.tstack->push(.Bool)

    case .Less_Than:
        t := p.tstack->pop()
        p.tstack->pop()
        emit(f, token, Less{})
        p.tstack->push(.Bool)

    case .Not_Equal:
        t := p.tstack->pop()
        p.tstack->pop()
        emit(f, token, Not_Equal{})
        p.tstack->push(.Bool)

    }

    return true
}

bind_words :: proc(p: ^Parser, f: ^Function, t: []Token) {
    check_scope := p.curr_scope
    new_binds_count := len(t)

    for check_scope != nil {
        for &e in check_scope.entities {
            #partial switch &v in e.variant {
                case Entity_Binding: v.index += new_binds_count
            }
        }
        check_scope = check_scope.parent
    }

    #reverse for word, index in t {
        T := p.tstack->pop()
        append(&p.curr_scope.entities, Entity{
            address = get_local_address(f),
            pos = word.pos,
            name = word.text,
            variant = Entity_Binding{kind = T, index = index},
        })
    }
}
