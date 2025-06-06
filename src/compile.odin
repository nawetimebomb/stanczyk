package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strconv"
import "core:strings"

Constant_Value :: union { bool, int, string }

Arity :: distinct [dynamic]^Type

Entity_Binding :: struct {
    type:  ^Type,
    index: int,
}

Entity_Constant :: struct {
    type:  ^Type,
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

Entity_Variable :: struct {
    offset: uint,
    size:   uint,
    type:   ^Type,
}

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

    called:    bool,
    errored:   bool,
    local_ip:  uint,
    local_mem: uint,

    code:      Code,
    stack:     Stack,
}

Scope_Kind :: enum u8 {
    Invalid,
    Function,
    Global,
    If,
    If_Else,
    Let,
    Do,
    For_Range,
}

Entities :: distinct [dynamic]Entity

Scope :: struct {
    kind:   Scope_Kind,
    token:  Token,
    parent: ^Scope,
    level:  int,

    start_op: ^Bytecode,

    entities:     Entities,
    stack_copies: [dynamic][]^Type,

    validation_at_end: enum {
        Skip,
        Stack_Is_Unchanged,
        Stack_Match_Between,
    },
}

Checker :: struct {
    curr_function: ^Function,
    curr_scope:    ^Scope,

    prev_token: Token,
    curr_token: Token,
    tokenizer:  Tokenizer,

    basic_types: [Type_Basic_Kind]^Type,

    errors: [dynamic]string,
}

gscope: ^Scope
checker: ^Checker

functions        := make([dynamic]Function)
C_functions      := make([dynamic]string)
strings_table    := map[string]int{}
global_mem_count := uint(0)

// Compilation error are not fatal, but will skip function parsing/compilation
// and save the error to the Checker. Errors added to the checker will be reported
// at the end of compilation.
compilation_error :: proc(f: ^Function, format: string, args: ..any) {
    pos := f.entity.pos

    fmt.assertf(
        checker.curr_function != nil,
        "compilation error can only happen when compiling a function content",
    )

    eb := strings.builder_make()
    fmt.sbprintf(&eb, "%s(%d:%d) compilation error in function {}: ",
                 pos.filename, pos.line, pos.column, f.entity.name)
    fmt.sbprintf(&eb, format, ..args)
    fmt.sbprint(&eb, "\n")
    append(&checker.errors, strings.to_string(eb))
    f.errored = true
}

// Parsing errors are fatal. We can't really know if the code following this
// error can be parsed correctly, so we need to forcibly exit.
parsing_error :: proc(pos: Position, format: string, args: ..any) {
    for err in checker.errors {
        fmt.eprint(err)
    }

    if len(checker.errors) > 0 {
        fmt.eprintfln("\nBut an error was encountered that stop compilation:\n")
    }

    fmt.eprintf("%s(%d:%d) parsing error: ", pos.filename, pos.line, pos.column)
    fmt.eprintfln(format, ..args)
    os.exit(1)
}

// Stack errors are fatal. We can't continue compiling because this would mean that
// all the following functions are going to also fail for the same reason.
stack_error :: proc(pos: Position, format: string, args: ..any) {
    // TODO: Fail when stack doesn't match, when stack is missing, and report position of the error and who called it.
}

push_string :: proc(v: string) -> int {
    id, ok := strings_table[v]
    if !ok {
        id = len(strings_table)
        strings_table[v] = id
    }
    return id
}

add_global_bool_constant :: proc(name: string, value: bool) {
    append(&gscope.entities, Entity{
        is_global = true,
        name = name,
        variant = Entity_Constant{
            type = checker.basic_types[.Bool],
            value = value,
        },
    })
}

add_global_string_constant :: proc(name: string, value: string) {
    append(&gscope.entities, Entity{
        is_global = true,
        name = name,
        variant = Entity_Constant{
            type = checker.basic_types[.String],
            value = push_string(value),
        },
    })
}

allow :: proc(kind: Token_Kind) -> bool {
    if checker.curr_token.kind == kind {
        next()
        return true
    }
    return false
}

emit :: proc(f: ^Function, token: Token, v: Bytecode_Variant) -> ^Bytecode {
    append(&f.code, Bytecode{
        address = get_local_address(f),
        pos = token.pos,
        variant = v,
    })
    return &f.code[len(f.code) - 1]
}

expect :: proc(kind: Token_Kind) -> Token {
    token := next()

    if token.kind != kind {
        parsing_error(
            token.pos,
            "expected %q, got %s",
            token_string_table[kind],
            token_to_string(token),
        )
    }

    return token
}

next :: proc() -> Token {
    token, err := get_next_token(&checker.tokenizer)
    if err != nil && token.kind != .EOF {
        parsing_error(token.pos, "found invalid token: %v", err)
    }
    checker.prev_token, checker.curr_token = checker.curr_token, token
    return checker.prev_token
}

peek :: proc() -> Token_Kind {
    return checker.curr_token.kind
}

compile :: proc() {
    checker = &Checker{}
    init_generator()
    init_everything()

    for source in source_files {
        tokenizer_init(&checker.tokenizer, source)
        next()

        first_loop: for {
            token := next()

            #partial switch token.kind {
                case .Using: parse_using()
                case .Const: declare_const()
                case .Var: declare_var()
                case .Foreign: {
                    if allow(.Fn) {
                        declare_func(.Foreign)
                        expect(.Dash_Dash_Dash)
                    } else {
                        unimplemented()
                    }
                }
                case .Fn: {
                    declare_func()
                    scope_level := 1

                    body_loop: for {
                        token := next()

                        #partial switch token.kind {
                            case .Const: scope_level += 1
                            case .Var: scope_level += 1
                            case .Fn: scope_level += 1
                            case .EOF: parsing_error(
                                token.pos, "unexpected end of file",
                            )
                            case .Semicolon: {
                                scope_level -= 1
                                if scope_level == 0 { break body_loop }
                            }
                        }
                    }
                }
                case .EOF: break first_loop
                case: parsing_error(
                    token.pos, "unexpected token of type %s", token_to_string(token),
                )
            }
        }
    }

    for source in source_files {
        tokenizer_init(&checker.tokenizer, source)
        next()

        parsing_loop: for {
            token := next()

            #partial switch token.kind {
                case .EOF: break parsing_loop
                case .Foreign: {
                    skip_to_end: for {
                        if next().kind == .Dash_Dash_Dash {
                            break skip_to_end
                        }
                    }
                }
                case .Fn: {
                    name_token := expect(.Word)
                    parsing_entity: ^Entity

                    // Searching the function by its token
                    for &other in gscope.entities {
                        if other.token == name_token {
                            parsing_entity = &other
                            break
                        }
                    }

                    if parsing_entity == nil {
                        parsing_error(
                            name_token.pos,
                            "compiler error failed to find Function entity",
                        )
                    }

                    if allow(.Paren_Left) {
                        skip_to_body: for {
                            if next().kind == .Paren_Right {
                                break skip_to_body
                            }
                        }
                    }

                    parse_function(parsing_entity)
                }
            }
        }
    }

    if len(checker.errors) > 0 {
        for err in checker.errors {
            fmt.eprintln(err)
        }

        os.exit(1)
    }

    gen_program()
    deinit_everything()
}

init_everything :: proc() {
    gscope = push_scope(Token{}, .Global)

    // Add compiler defined constants
    add_global_bool_constant("OS_DARWIN", ODIN_OS == .Darwin)
    add_global_bool_constant("OS_LINUX", ODIN_OS == .Linux)
    add_global_bool_constant("OS_WINDOWS", ODIN_OS == .Windows)
    add_global_bool_constant("SK_DEBUG", debug_switch_enabled)

    add_global_string_constant("SK_VERSION", COMPILER_VERSION)

    checker.basic_types = {
            .Bool   = new_clone(Type{size = 1, variant = Type_Basic{.Bool}}, context.temp_allocator),
            .Byte   = new_clone(Type{size = 1, variant = Type_Basic{.Byte}}, context.temp_allocator),
            .Int    = new_clone(Type{size = 8, variant = Type_Basic{.Int}}, context.temp_allocator),
            .String = new_clone(Type{size = 8, variant = Type_Basic{.String}}, context.temp_allocator),
    }
}

deinit_everything :: proc() {
    assert(checker.curr_scope.parent == nil)
    delete_scope(checker.curr_scope)
    assert(checker.curr_function == nil)

    for &f in functions {
        f.stack->free()
        delete(f.code)
    }

    delete(strings_table)
    delete(C_functions)
}

find_entity :: proc(token: Token) -> Entity {
    possible_matches := make(Entities, context.temp_allocator)
    name := token.text
    test_scope := checker.curr_scope
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
        parsing_error(token.pos, "undefined word '%s'", name)
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

            if len(checker.curr_function.stack.v) >= len(test.inputs) {
                stack_copy := slice.clone(checker.curr_function.stack.v[:])
                defer delete(stack_copy)
                slice.reverse(stack_copy[:])
                sim_test_stack := stack_copy[:len(test.inputs)]
                func_test_stack := make([dynamic]^Type, context.temp_allocator)
                defer delete(func_test_stack)

                for input in test.inputs {
                    append(&func_test_stack, input)
                }

                if slice.equal(sim_test_stack, func_test_stack[:]) {
                    append(&matches, Match_Stats{
                        entity = other,
                        exact_number_inputs = len(checker.curr_function.stack.v) == len(test.inputs),
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
                            fmt.sbprintf(&builder, "{})", type_to_string(input))
                        } else {
                            fmt.sbprintf(&builder, "{} ", type_to_string(input))
                        }
                    }
                    if len(ef.outputs) > 0 {
                        fmt.sbprint(&builder, "--- ")
                        for output, index in ef.outputs {
                            if index == len(ef.outputs) - 1 {
                                fmt.sbprintf(&builder, "{})", type_to_string(output))
                            } else {
                                fmt.sbprintf(&builder, "{} ", type_to_string(output))
                            }
                        }
                    }
                    fmt.sbprint(&builder, "\n")
                }
            }

            return strings.to_string(builder)
        }

        // Unfortunately we couldn't find a reliable result, so we error out.
        parsing_error(
            token.pos,
            "unable to find matching function of name '{}' with stack {}{}",
            token.text,
            checker.curr_function.stack.v,
            report_posible_matches(possible_matches[:]),
        )
    }

    return Entity{}
}

push_function :: proc(entity: ^Entity) -> ^Scope {
    // TODO: This only support global functions, which I think it's fine, but if at some point
    // we want to support functions inside another function scope, we need to allow it here.
    for &f in functions {
        if f.entity.token == entity.token {
            checker.curr_function = &f
            break
        }
    }

    fmt.assertf(checker.curr_function != nil, "missing {}", entity.name)

    return push_scope(entity.token, .Function)
}

pop_function :: proc() {
    assert(checker.curr_function != nil)
    pop_scope()
    checker.curr_function = checker.curr_function.parent
}

push_scope :: proc(t: Token, k: Scope_Kind) -> ^Scope {
    checker.curr_scope = new_clone(Scope{
        token = t,
        entities = make(Entities, context.temp_allocator),
        parent = checker.curr_scope,
        level = checker.curr_scope == nil ? 0 : checker.curr_scope.level + 1,
        kind = k,
    })
    return checker.curr_scope
}

pop_scope :: proc() {
    assert(checker.curr_scope != nil)
    assert(checker.curr_function != nil)

    switch checker.curr_scope.validation_at_end {
    case .Skip:
        // Do nothing
    case .Stack_Is_Unchanged:
        // The stack hasn't changed in length and types. It only supports one stack copy
        stack_copies := &checker.curr_scope.stack_copies
        assert(len(stack_copies) > 0)

        if len(stack_copies) != 1 {
            for A, index in checker.curr_function.stack.v {
                B := stack_copies[0][index]
                if !types_equal(A, B) {
                    parsing_error(
                        checker.curr_scope.token,
                        "stack changes not allowed on this scope block\n\tBefore: {}\n\tAfter: {}",
                        stack_copies[0], checker.curr_function.stack.v,
                    )
                }
            }
        }
    case .Stack_Match_Between:
        // The stack has to have the same result between its branching values
        stack_copies := &checker.curr_scope.stack_copies

        for i in 0..<len(stack_copies) - 1 {
            for _, j in stack_copies[i] {
                A, B := stack_copies[i][j], stack_copies[i + 1][j]

                if !types_equal(A, B) {
                    parsing_error(
                        checker.curr_scope.token,
                        "different stack effects between scopes not allowed",
                    )
                }
            }
        }
    }

    for item in checker.curr_scope.stack_copies {
        delete(item)
    }

    // Realign bindings after the scope is closed
    binds_count_in_scope := 0

    for e in checker.curr_scope.entities {
        if _, ok := e.variant.(Entity_Binding); ok {
            binds_count_in_scope += 1
        }
    }

    update_scope := checker.curr_scope.parent

    for update_scope != nil {
        for &e in update_scope.entities {
            #partial switch &v in e.variant {
                case Entity_Binding: v.index -= binds_count_in_scope
            }
        }

        update_scope = update_scope.parent
    }

    old_scope := checker.curr_scope
    checker.curr_scope = old_scope.parent
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

create_stack_snapshot :: proc(f: ^Function, s: ^Scope) {
    append(&s.stack_copies, slice.clone(f.stack.v[:]))
}

refresh_stack_snapshot :: proc(f: ^Function, s: ^Scope) {
    delete(pop(&s.stack_copies))
    create_stack_snapshot(f, s)
}

declare_const :: proc() {
    name_token := expect(.Word)
    name := name_token.text
    f := checker.curr_function
    ec := Entity_Constant{}
    entities := &checker.curr_scope.entities
    inferred_type: ^Type
    temp_value_stack := make([dynamic]Constant_Value, context.temp_allocator)
    defer delete(temp_value_stack)

    if allow(.Type_Literal) {
        ec.type = type_string_to_Type(checker.prev_token.text)
    }

    body_loop: for {
        token := next()
        #partial switch token.kind {
            case .EOF: parsing_error(token.pos, "unexpected end of file")
            case .Semicolon: break body_loop
            case .Word: {
                // Check if this constant is a compiler-defined constant (because the name is the same as the value)
                if token.text == name {
                    if len(temp_value_stack) > 0 {
                        // This can't be true, the compiler-defined constant should be the only value.
                        parsing_error(token.pos, "unexpected values in supposed compiler-defined constant {}", name)
                    }

                    found := false
                    for e in gscope.entities {
                        if e.name == name {
                            found = true
                            break
                        }
                    }
                    if !found {
                        parsing_error(token.pos, "constant {} is not actually compiler-defined", name)
                    }

                    expect(.Semicolon)
                    return
                }

                // This is some dirty stuff but we have to manage basic operations internally
                // Because +, -, /, *, % are not internal functionality, we need to do this
                // within the compiler.
                switch token.text {
                case "+", "-", "%", "/", "*":
                    v2 := pop(&temp_value_stack)
                    v1 := pop(&temp_value_stack)
                    switch token.text {
                    case "+": append(&temp_value_stack, v1.(int) + v2.(int))
                    case "/": append(&temp_value_stack, v1.(int) / v2.(int))
                    case "%": append(&temp_value_stack, v1.(int) % v2.(int))
                    case "*": append(&temp_value_stack, v1.(int) * v2.(int))
                    case "-": append(&temp_value_stack, v1.(int) - v2.(int))
                    }
                case :
                    entity := find_entity(token)
                    v, ok := entity.variant.(Entity_Constant)

                    if !ok {
                        parsing_error(
                            token.pos,
                            "'{}' is not a compile-time known constant",
                        )
                    }

                    if inferred_type != nil && inferred_type != v.type {
                        compilation_error(
                            f,  "word '{}' of type '{}' cannot be used in expected type of {}",
                            entity.name, type_to_string(v.type), inferred_type,
                        )
                    }

                    inferred_type = v.type

                    if types_equal(v.type, checker.basic_types[.Int]) {
                        append(&temp_value_stack, v.value)
                    } else {
                        ec.value = v.value
                        expect(.Semicolon)
                        break body_loop
                    }
                }
            }
            case .Bool_Literal: {
                ec.value = token.text == "true" ? true : false
                inferred_type = checker.basic_types[.Bool]
                expect(.Semicolon)
                break body_loop
            }
            case .Cstring_Literal: unimplemented()
            case .Integer_Literal: {
                append(&temp_value_stack, strconv.atoi(token.text))
                if inferred_type == nil {
                    inferred_type = checker.basic_types[.Int]
                } else if inferred_type != checker.basic_types[.Int] {
                    parsing_error(
                        token.pos,
                        "can't mix type of values in constant",
                    )
                }
            }
            case .String_Literal: {
                ec.value = token.text
                inferred_type = checker.basic_types[.String]
                expect(.Semicolon)
                break body_loop
            }
        }
    }

    if ec.type == nil {
        ec.type = inferred_type
    } else if !types_equal(ec.type, inferred_type) {
        parsing_error(
            name_token,
            "type declaration of {} doesn't match value type of {} in constant '{}'",
            type_to_string(ec.type), type_to_string(inferred_type), name,
        )
    }

    if len(temp_value_stack) > 0 {
        if len(temp_value_stack) != 1 {
            parsing_error(
                name_token,
                "values in constant don't compile to a single value",
            )
        }

        ec.value = pop(&temp_value_stack)
    }

    if name == "main" {
        parsing_error(
            name_token.pos,
            "main is a reserved word for the entry point function of the program",
        )
    }

    for other in entities {
        if other.name == name {
            parsing_error(
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

declare_func :: proc(kind: enum { Default, Builtin, Foreign } = .Default) {
    name_token := expect(.Word)
    name := name_token.text
    is_foreign := kind == .Foreign
    is_builtin := kind == .Builtin
    foreign_name := name
    address := get_global_address()
    entities := &checker.curr_scope.entities
    is_main := false
    ef := Entity_Function{
        inputs = make(Arity),
        outputs = make(Arity),
    }

    if is_foreign {
        if allow(.As) {
            foreign_name = name
            name_token = expect(.Word)
            name = name_token.text
        }

        append(&C_functions, foreign_name)
    }

    parse_function_head(&ef)

    if name == "main" {
        gen.main_func_address = address
        is_main = true
    }

    for &other in entities {
        if other.name == name {
            if is_main {
                parsing_error(
                    name_token.pos, "redeclared main in {}:{}:{}",
                    other.filename, other.line, other.column,
                )
            }

            #partial switch &v in other.variant {
                case Entity_Function: {
                    if v.has_any_input || ef.has_any_input {
                        err_token := v.has_any_input ? other.token : name_token
                        parsing_error(err_token.pos, "a function with 'any' input exists and it can't be polymorphic")
                    }

                    if v.is_parapoly || ef.is_parapoly {
                        err_token := v.is_parapoly ? other.token : name_token
                        parsing_error(err_token.pos, "parapoly functions can't be polymorphic")
                    }

                    v.is_polymorphic = true
                    ef.is_polymorphic = true
                }
                case: parsing_error(
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
        })
    }
}

parse_function_head :: proc(ef: ^Entity_Function) {
    if allow(.Paren_Left) {
        if !allow(.Paren_Right) {
            arity := &ef.inputs
            outputs := false

            arity_loop: for {
                token := next()

                #partial switch token.kind {
                    case .Paren_Right: break arity_loop
                    case .Dash_Dash_Dash: {
                        arity = &ef.outputs
                        outputs = true
                    }
                    case .Word: {
                        ef.is_parapoly = true
                        append(arity, type_string_to_Type(token.text))
                    }
                    case .Type_Literal: {
                        T := type_string_to_Type(token.text)

                        if type_is_any(T) {
                            ef.has_any_input = true

                            if outputs {
                                parsing_error(
                                    token.pos,
                                    "functions can't have 'Any' as outputs",
                                )
                            }
                        }
                        append(arity, T)
                    }
                    case: parsing_error(
                        token.pos, "unexpected token %s", token_to_string(token),
                    )
                }
            }
        }
    }
}

declare_var :: proc() {
    name_token := expect(.Word)
    name := name_token.text
    is_global := checker.curr_scope == gscope
    entities := &checker.curr_scope.entities
    ev := Entity_Variable{}
    address: uint

    type_lit_token := expect(.Type_Literal)
    ev.type = checker.basic_types[type_string_to_basic(type_lit_token.text)]

    if is_global {
        address = get_global_address()
        ev.offset = global_mem_count
        global_mem_count += ev.size
    } else {
        f := checker.curr_function
        address = get_local_address(f)
        ev.offset = f.local_mem
        f.local_mem += ev.size
    }

    expect(.Semicolon)

    append(entities, Entity{
        address = address,
        pos = name_token.pos,
        name = name,
        variant = ev,
    })
}

parse_using :: proc() {
    using_loop: for {
        t := next()

        #partial switch t.kind {
            case .Semicolon: break using_loop
            case .Word: {
                dir := "base"
                filename := t.text

                if strings.contains(filename, ".") {
                    dir, _, filename = strings.partition(filename, ".")
                }

                load_file(
                    fmt.tprintf("{}.sk", filename), false,
                    fmt.tprintf("{}/{}", compiler_dir, dir),
                )
            }
            case: {
                parsing_error(
                    t.pos,
                    "expected words in 'using' statement, got {}",
                    token_string_table[t.kind],
                )
            }
        }
    }
}

call_foreign_func :: proc(f: ^Function, t: Token, e: Entity) {
    ef := e.variant.(Entity_Function)

    #reverse for input in ef.inputs {
        A := f.stack->pop()

        if !types_equal(input, A) {
            compilation_error(
                f, "input mismatch in function {}\n\tExpected: {},\tHave: {}",
                t.text, type_to_string(input), type_to_string(A),
            )
        }
    }

    b := emit(f, t, Call_C_Function{
        name = e.foreign_name,
        inputs = len(ef.inputs),
        outputs = len(ef.outputs),
    })

    for output in ef.outputs {
        f.stack->push(output)
    }
}

call_builtin_func :: proc(f: ^Function, t: Token, e: Entity) {
    ef := e.variant.(Entity_Function)
}

call_function :: proc(entity: Entity, loc := #caller_location) {
    f := checker.curr_function
    ef := entity.variant.(Entity_Function)
    token := checker.prev_token
    parapoly_table := make(map[string]^Type, context.temp_allocator)
    defer delete(parapoly_table)

    #reverse for input in ef.inputs {
        A := f.stack->pop()

        switch {
        case type_is_polymorphic(input):
            v, ok := parapoly_table[input.name]

            if !ok {
                parapoly_table[input.name] = A
                v = A
            }

            if A != v {
                compilation_error(
                    checker.curr_function,
                    "parapoly of name '{}' means '{}' in this declaration, got '{}'",
                    input.name, type_to_string(v), type_to_string(A),
                )
            }
        case !types_equal(input, A) && !type_is_any(input):
            compilation_error(
                checker.curr_function,
                "input mismatch in function {}\n\tExpected: {},\tHave: {}",
                token.text, input, A,
            )
        }
    }

    // Mark the function as called.
    for &f in functions {
        if f.entity.token == entity.token { f.called = true }
    }

    b := emit(f, token, Call_Function{
        address = entity.address,
        name = entity.name,
    })

    for output in ef.outputs {
        if type_is_polymorphic(output) {
            v, ok := parapoly_table[output.name]

            if !ok {
                compilation_error(
                    checker.curr_function,
                    "parapoly of the name {} not defined in inputs",
                    output.name,
                )
            }

            f.stack->push(v)
        } else {
            f.stack->push(output)
        }
    }
}

parse_function :: proc(e: ^Entity) {
    ef := e.variant.(Entity_Function)
    push_function(e)
    f := checker.curr_function
    stack_create(f)

    for T in ef.inputs {
        f.stack->push(T)
    }

    body_loop: for {
        if f.errored {
            for {
                if next().kind == .Semicolon {
                    break body_loop
                }
            }
        }

        if !parse_token(next(), f) {
            break body_loop
        }
    }

    // TODO: Improve error message
    // stack_expect(
    //     e.pos,
    //     fmt.tprintf(
    //         "mismatched outputs in function {}.\n\tExpected: {}\n\tGot: {}",
    //         e.name, ef.outputs, f.stack.v,
    //     ),
    //     stack_match_arity(f.stack.v[:], ef.outputs),
    // )

    pop_function()
}

parse_token :: proc(token: Token, f: ^Function) -> bool {
    switch token.kind {
    case .EOF, .Invalid, .Fn, .Using, .Dash_Dash_Dash, .Foreign:
        parsing_error(
            token.pos,
            "invalid token in function body {}",
            token_to_string(token),
        )

    case .Semicolon:
        emit(f, token, Return{})
        return false

    case .Const: declare_const()
    case .Var:   declare_var()

    case .Word: parse_word(f, token)
    case .As:
    case .Let:
        scope := push_scope(token, .Let)
        words := make([dynamic]Token, context.temp_allocator)
        defer delete(words)

        for !allow(.In) {
            token := expect(.Word)
            append(&words, token)
        }

        bind_words(f, words[:])
        emit(f, token, Let_Bind{len(words)})

    case .In: unimplemented()

    case .End:
        if checker.curr_scope.kind == .Let {
            binds_count := 0

            for e in checker.curr_scope.entities {
                if _, ok := e.variant.(Entity_Binding); ok {
                    binds_count += 1
                }
            }

            emit(f, token, Let_Unbind{binds_count})
        }

        pop_scope()

    case .Case: unimplemented()

    case .If:
        A := f.stack->pop()

        if !types_equal(A, checker.basic_types[.Bool]) {
            compilation_error(f, "Non-boolean condition in 'if' statement")
        }

        scope := push_scope(token, .If)
        scope.validation_at_end = .Stack_Is_Unchanged
        scope.start_op = emit(f, token, If{})
        create_stack_snapshot(f, scope)
        f.stack->save()

    case .Else:
        if checker.curr_scope.kind != .If {
            compilation_error(f, "'else' unattached to an 'if' statement")
        }

        checker.curr_scope.kind = .If_Else
        checker.curr_scope.validation_at_end = .Stack_Match_Between
        refresh_stack_snapshot(f, checker.curr_scope)
        f.stack->reset()
        b := emit(f, token, Else{checker.curr_scope.start_op.address})
        checker.curr_scope.start_op = b

    case .Fi:
        should_error := true
        close_if_statements: for {
            switch {
            case checker.curr_scope.kind == .If:
                b := emit(f, token, Fi{checker.curr_scope.start_op.address})
                should_error = false
                pop_scope()
                f.stack->reset()
            case checker.curr_scope.kind == .If_Else:
                b := emit(f, token, Fi{checker.curr_scope.start_op.address})
                should_error = false
                create_stack_snapshot(f, checker.curr_scope)
                pop_scope()
            case :
                if should_error {
                    compilation_error(f, "'fi' unattached to an 'if' statement")
                }
                break close_if_statements
            }
        }

    case .For: parse_for_op(f, token)
    case .Do:
        A := f.stack->pop()

        stack_expect(
            token.pos,
            "Non-boolean condition in 'do' statement",
            types_equal(A, checker.basic_types[.Bool]),
        )

        scope := push_scope(token, .Do)
        scope.validation_at_end = .Stack_Is_Unchanged
        scope.start_op = emit(f, token, Do{ use_self = true })
        create_stack_snapshot(f, scope)
        f.stack->save()

    case .Loop:
        #partial switch checker.curr_scope.kind {
            case .Do: {
                A := f.stack->pop()

                stack_expect(
                    token.pos,
                    "Non-boolean condition in 'loop' statement",
                    types_equal(A, checker.basic_types[.Bool]),
                )

                emit(f, token, Loop{
                    address = checker.curr_scope.start_op.address,
                    bindings = 0,
                })
                pop_scope()
                f.stack->reset()
            }
            case .For_Range: {
                A := f.stack->pop()

                stack_expect(
                    token.pos,
                    "(int) expected in range for loop",
                    types_equal(A, checker.basic_types[.Int]),
                )

                emit(f, token, Loop{
                    address = checker.curr_scope.start_op.address,
                    bindings = 1,
                })
                pop_scope()
            }
            case : compilation_error(
                f, "'loop' unattached to a 'for' or 'do' statement",
            )
        }

    case .Leave: emit(f, token, Return{})

    case .Brace_Left: unimplemented()
    case .Brace_Right: unimplemented()
    case .Bracket_Left: unimplemented()
    case .Bracket_Right: unimplemented()
    case .Paren_Left: unimplemented()
    case .Paren_Right: unimplemented()
    case .Binary_Literal: unimplemented()

    case .Character_Literal:
        emit(f, token, Push_Byte{token.text[0]})
        f.stack->push(checker.basic_types[.Byte])
    case .Bool_Literal:
        emit(f, token, Push_Bool{token.text == "true" ? true : false})
        f.stack->push(checker.basic_types[.Bool])
    case .Cstring_Literal:
        emit(f, token, Push_Cstring{
            push_string(token.text), len(token.text),
        })
        f.stack->push(checker.basic_types[.String])
        f.stack->push(checker.basic_types[.Int])
    case .Float_Literal: fmt.assertf(false, "unimplemented for now")
    case .Hex_Literal: unimplemented()
    case .Integer_Literal:
        emit(f, token, Push_Int{strconv.atoi(token.text)})
        f.stack->push(checker.basic_types[.Int])
    case .Octal_Literal: unimplemented()
    case .String_Literal:
        emit(f, token, Push_String{push_string(token.text)})
        f.stack->push(checker.basic_types[.String])
    case .Uint_Literal:
        emit(f, token, Push_Int{strconv.atoi(token.text)})
        f.stack->push(checker.basic_types[.Int])
    case .Type_Literal: unimplemented()

    case .Get:      parse_memory_op(f, token, .get)
    case .Get_Byte: parse_memory_op(f, token, .get_byte)
    case .Set:      parse_memory_op(f, token, .set)
    case .Set_Byte: parse_memory_op(f, token, .set_byte)

    case .Plus:          parse_binary_op(f, token, .add)
    case .Minus:         parse_binary_op(f, token, .sub)
    case .Star:          parse_binary_op(f, token, .mul)
    case .Slash:         parse_binary_op(f, token, .div)
    case .Percent:       parse_binary_op(f, token, .mod)
    case .Equal:         parse_binary_op(f, token, .eq)
    case .Greater_Equal: parse_binary_op(f, token, .ge)
    case .Greater_Than:  parse_binary_op(f, token, .gt)
    case .Less_Equal:    parse_binary_op(f, token, .le)
    case .Less_Than:     parse_binary_op(f, token, .lt)
    case .Not_Equal:     parse_binary_op(f, token, .ne)
    }

    return true
}

bind_words :: proc(f: ^Function, t: []Token) {
    check_scope := checker.curr_scope
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
        A := f.stack->pop()
        append(&checker.curr_scope.entities, Entity{
            address = get_local_address(f),
            pos = word.pos,
            name = word.text,
            variant = Entity_Binding{index = index, type = A},
        })
    }
}

parse_word :: proc(f: ^Function, t: Token) {
    if t.text == "println" || t.text == "print" {
        f.stack->pop()
        emit(f, t, Print{})
        return
    }
    result := find_entity(t)

    switch v in result.variant {
    case Entity_Binding:
        b := emit(f, t, Push_Bound{v.index})
        f.stack->push(v.type)
    case Entity_Constant:
        switch {
        case type_is_basic(v.type, .Bool):
            emit(f, t, Push_Bool{v.value.(bool)})
        case type_is_basic(v.type, .Int):
            emit(f, t, Push_Int{v.value.(int)})
        case type_is_basic(v.type, .String):
            emit(f, t, Push_String{push_string(v.value.(string))})
        }
        f.stack->push(v.type)
    case Entity_Function:
        switch {
        case result.is_builtin: call_builtin_func(f, t, result)
        case result.is_foreign: call_foreign_func(f, t, result)
        case: call_function(result)
        }
    case Entity_Variable:
        if result.is_global {
            emit(f, t, Push_Var_Global_Pointer{v.offset})
        } else {
            emit(f, t, Push_Var_Local_Pointer{v.offset})
        }
        f.stack->push(v.type)
    }
}

parse_binary_op :: proc(f: ^Function, t: Token, op: enum {
    add, sub, mul, div, mod, eq, ge, gt, le, lt, ne,
}) {
    B := f.stack->pop()
    A := f.stack->pop()

    // TODO: Add validations!
    switch op {
    case .add:
        emit(f, t, Add{})
        switch {
        case type_is_pointer(A): f.stack->push(A)
        case type_is_pointer(B): f.stack->push(B)
        case : f.stack->push(checker.basic_types[.Int])
        }
    case .sub:
        emit(f, t, Substract{})
        f.stack->push(checker.basic_types[.Int])
    case .mul:
        emit(f, t, Multiply{})
        f.stack->push(checker.basic_types[.Int])
    case .div:
        emit(f, t, Divide{})
        f.stack->push(checker.basic_types[.Int])
    case .mod:
        emit(f, t, Modulo{})
        f.stack->push(checker.basic_types[.Int])
    case .eq:
        emit(f, t, Equal{})
        f.stack->push(checker.basic_types[.Bool])
    case .ge:
        emit(f, t, Greater_Equal{})
        f.stack->push(checker.basic_types[.Bool])
    case .gt:
        emit(f, t, Greater{})
        f.stack->push(checker.basic_types[.Bool])
    case .le:
        emit(f, t, Less_Equal{})
        f.stack->push(checker.basic_types[.Bool])
    case .lt:
        emit(f, t, Less{})
        f.stack->push(checker.basic_types[.Bool])
    case .ne:
        emit(f, t, Not_Equal{})
        f.stack->push(checker.basic_types[.Bool])
    }
}

parse_memory_op :: proc(f: ^Function, t: Token, op: enum {
    get, get_byte, set, set_byte,
}) {
    switch op {
    case .get:
        A := f.stack->pop()
        emit(f, t, Get{})
        f.stack->push(checker.basic_types[.String])
    case .get_byte:
        B := f.stack->pop()
        A := f.stack->pop()
        emit(f, t, Get_Byte{})
        f.stack->push(checker.basic_types[.Byte])
    case .set:
        B := f.stack->pop()
        A := f.stack->pop()
        // Add validation for pointers
        emit(f, t, Set{})
    case .set_byte:
        B := f.stack->pop()
        A := f.stack->pop()
        emit(f, t, Set_Byte{})
    }
}

parse_for_op :: proc(f: ^Function, t: Token) {
    scope := push_scope(t, .Invalid)
    words := make([dynamic]Token, context.temp_allocator)
    defer delete(words)
    append(&words, expect(.Word))

    if allow(.Word) {
        append(&words, checker.prev_token)
    }

    expect(.In)

    // "for" support multiple types of looand in order to figure out what type of
    // loop we're going to be parsing here, we need to know more about the context.
    // Usually the first parameter in the loop will tell us exactly what to do.
    // The first parameter should ALWAYS push a value to the stack, and we're
    // inferring the desired loop with that value pushed into the stack.
    // pushing something to the stack.
    prev_stack_len := len(f.stack.v)
    parse_token(next(), f)

    if prev_stack_len > len(f.stack.v) {
        parsing_error(
            t.pos, "missing value in stack in statement 'for <bind> in'",
        )
    }

    // A tells us what to do
    A := f.stack->peek()

    if type_is_basic(A, .Int) {
        // This is the regular range for loop
        if len(words) != 1 {
            compilation_error(
                f, "'for' loop of type range can only have one word bound",
            )
        }

        // We're doing implicit binding here, that means we take the necessary words
        // out of the stack, but then, this operation also emits a value into the
        // stack (the previously bound value), so we re-add it as part of the emit.
        bind_words(f, words[:])
        scope.start_op = emit(f, t, For_Range{})
        f.stack->push(A)
        scope.kind = .For_Range
        parse_token(next(), f)
        parse_token(next(), f)

        B := f.stack->pop()

        if !type_is_basic(B, .Bool) {
            compilation_error(f, "Non-boolean condition in 'for' range statement")
        }

        emit(f, expect(.Do), Do{
            address = scope.start_op.address,
            use_self = false,
        })

        create_stack_snapshot(f, scope)
        f.stack->save()
    } else if type_is_basic(A, .String) {
        // This is a string iteration. We are looking into the string's characters.
        unimplemented()
    } else {
        unimplemented()
    }
}
