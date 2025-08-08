package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strconv"
import "core:strings"

Entities :: distinct [dynamic]Entity

Scope_Kind :: enum u8 {
    Invalid,
    Global,
    Procedure,
    If, If_Else, Let,
    Loop,
}

Entity :: struct {
    foreign_name: string,
    name:         string,
    token:        Token,
    variant:      Entity_Variant,
}

Entity_Variant :: union {
    Entity_Binding,
    Entity_Constant,
    Entity_Procedure,
    Entity_Type,
    Entity_Variable,
}

Entity_Binding :: struct {
    type:     ^Type,
    index:    int,
    internal: bool,
    mutable:  bool,
}

Entity_Constant :: struct {
    value: ^Ast,
}

Entity_Procedure :: struct {
    params:  []^Ast,
    results: []^Ast,
}

Entity_Type :: struct {
    type: ^Type,
}

Entity_Variable :: struct {
    value: ^Ast,
}

Stack :: struct {
    clear: proc(^Stack),
    push:  proc(^Stack, ^Ast),
    pop:   proc(^Stack) -> ^Ast,
    data:  [dynamic]^Ast,
}

Scope :: struct {
    ast:      ^Ast,
    address:  int,
    entities: Entities,
    kind:     Scope_Kind,
    level:    int,
    parent:   ^Scope,
    token:    Token,
}

Parser :: struct {
    curr_scope:     ^Scope,
    proc_scope:     ^Scope,
    global_scope:   ^Scope,
    known_types:    map[string]^Type,

    prev_token:     Token,
    curr_token:     Token,
    tokenizer:      Tokenizer,
    errors:         [dynamic]string,

    program:        [dynamic]^Ast,
}

parser: ^Parser
stack: Stack

allow :: proc(kind: Token_Kind) -> bool {
    if parser.curr_token.kind == kind {
        next()
        return true
    }
    return false
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
    token, err := get_next_token(&parser.tokenizer)

    if err != nil && token.kind != .EOF {
        parsing_error(token.pos, "found invalid token: %v", err)
    }

    parser.prev_token, parser.curr_token = parser.curr_token, token

    return parser.prev_token
}

push_scope :: proc(kind: Scope_Kind, token := Token{}) -> ^Scope {
    parser.curr_scope = new_clone(Scope{
        entities = make(Entities),
        parent   = parser.curr_scope,
        level    = parser.curr_scope == nil ? 0 : parser.curr_scope.level + 1,
        kind     = kind,
        token    = token,
    })

    return parser.curr_scope
}

pop_scope :: proc() {
    assert(parser.curr_scope != nil)
    parser.curr_scope = parser.curr_scope.parent
}

register_const :: proc() {
    name_token := expect(.Word)
    name_str := name_token.text
    ec := Entity_Constant{}

    if allow(.Word) {
        maybe_type_token := parser.prev_token
        maybe_type := type_from_string(maybe_type_token.text)

        if maybe_type == nil {
            ec.value, _ = parse_identifier_statement(maybe_type_token)
        }
    }

    for !allow(.Semicolon) {
        ec.value, _ = parse_statement()
    }

    if ec.value == nil {
        if len(stack.data) != 1 {
            parsing_error(name_token.pos, "only one value can be stored")
        }

        ec.value = stack->pop()
    }

    if _, ok := ec.value.variant.(Ast_Literal); !ok {
        parsing_error(name_token.pos, "value is not compile-time known constant")
    }

    for other in parser.curr_scope.entities {
        if other.name == name_str {
            filename, line, column := token_pos(other.token)
            parsing_error(
                name_token.pos, "redeclaration of '{}' in {}:{}:{}",
                name_str, filename, line, column,
            )
        }
    }

    add_entity(Entity{name = name_str, token = name_token, variant = ec})
}

register_proc :: proc(is_foreign := false) {
    name_token := expect(.Word)
    name_str := name_token.text
    ep := Entity_Procedure{}
    foreign_name := ""

    if is_foreign {
        foreign_name = name_str

        if allow(.Like) {
            name_token = expect(.Word)
            name_str = name_token.text
        }
    }

    if allow(.Paren_Left) {
        if !allow(.Paren_Right) {
            params  := make([dynamic]^Ast)
            results := make([dynamic]^Ast)
            defer delete(params)
            defer delete(results)

            arity := &params
            arity_index := 0

            arity_loop: for {
                token := next()

                #partial switch token.kind {
                    case .Semicolon: parsing_error(token.pos, "missing ')' on procedure definition")
                    case .Paren_Right: break arity_loop
                    case .Dash_Dash_Dash: arity = &results
                    case .Word: {
                        node := create_node()
                        arity_name := fmt.aprintf("{}{}", GENERIC_STRUCT_FIELD_NAME, arity_index)

                        node.type = type_from_string(token.text)
                        node.variant = Ast_Identifier{
                            foreign_name = arity_name,
                            name         = arity_name,
                        }

                        append(arity, node)
                    }
                }

                arity_index += 1
            }

            ep.params  = slice.clone(params[:])
            ep.results = slice.clone(results[:])
        }
    }

    for other in parser.curr_scope.entities {
        if other.name == name_str {
            filename, line, column := token_pos(other.token)
            parsing_error(
                name_token.pos, "redeclaration of '{}' in {}:{}:{}",
                name_str, filename, line, column,
            )
        }
    }

    add_entity(Entity{name = name_str, token = name_token, variant = ep, foreign_name = foreign_name})
}

add_entity :: proc(base_ent: Entity) {
    assert(parser.curr_scope != nil)
    ent := base_ent

    if ent.foreign_name == "" {
        ent.foreign_name = create_foreign_name(ent.token.filename, ent.name)
    }

    append(&parser.curr_scope.entities, ent)
}

create_foreign_name :: proc(filename: string, stanczyk_name: string) -> string {
    VALID :: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"

    is_global_scope := parser.curr_scope == parser.global_scope
    foreign_name_builder := strings.builder_make()

    if is_global_scope && stanczyk_name == "main" {
        strings.write_string(&foreign_name_builder, "stanczyk__main")
    } else {
        strings.write_string(&foreign_name_builder, filepath.short_stem(filename))
        strings.write_string(&foreign_name_builder, "__")

        snake_name := strings.to_snake_case(stanczyk_name)

        for r in snake_name {
            if strings.contains_rune(VALID, r) {
                strings.write_rune(&foreign_name_builder, r)
            }
        }
    }

    return strings.to_string(foreign_name_builder)
}

find_entity :: proc(name: string) -> ^Entity {
    result: ^Entity
    scope := parser.curr_scope

    search_loop: for scope != nil {
        for &ent in scope.entities {
            if ent.name == name {
                result = &ent
                break search_loop
            }
        }

        scope = scope.parent
    }

    if result == nil {
        parsing_error(parser.prev_token.pos, "{} is undefined", name)
    }

    assert(result != nil)
    return result
}

create_node :: proc() -> ^Ast {
    node := new(Ast)
    node.token = parser.prev_token
    return node
}

create_local_name :: proc(prefix := "sk") -> string {
    // fmt.assertf(parser.curr_scope != nil, "called outside a procedure by token {}", parser.prev_token)
    name := strings.builder_make()
    fmt.sbprintf(&name, "{}{}", prefix, parser.curr_scope.address)
    parser.curr_scope.address += 1
    return strings.to_string(name)
}

parsing_error :: proc(pos: Position, format: string, args: ..any) {
    for err in parser.errors {
        fmt.eprint(err)
    }

    if len(parser.errors) > 0 {
        fmt.eprintfln("\nBut an error was encountered that stop compilation:\n")
    }

    fmt.eprintf("%s(%d:%d) parsing error: ", pos.filename, pos.line, pos.column)
    fmt.eprintfln(format, ..args)
    os.exit(1)
}

unexpected_end_of_file :: proc() {
    parsing_error(parser.prev_token.pos, "unexpected end of file")
}

compiler_bug :: proc(details: string = "not specified by the compiler developer", loc := #caller_location) {
    parsing_error(parser.prev_token.pos, "COMPILER BUG: This is an error on the compiler, not on the Stańczyk code.\nThe root cause for this might be: %s\nCalled from: %s", details, loc)
}

parse_proc_decl :: proc(token: Token) -> ^Ast {
    node := create_node()
    name_token := expect(.Word)
    ent := find_entity(name_token.text)
    ep, ok := ent.variant.(Entity_Procedure)
    assert(ok)

    proc_decl := Ast_Proc_Decl{
        body         = make([dynamic]^Ast),
        params       = slice.clone(ep.params[:]),
        foreign_name = ent.foreign_name,
        name         = ent.name,
    }

    if allow(.Paren_Left) {
        for !allow(.Paren_Right) { next() }
    }

    proc_scope := push_scope(.Procedure, node.token)
    proc_decl.scope = proc_scope
    parser.proc_scope = proc_scope

    for param in ep.params {
        variant, ok := param.variant.(Ast_Identifier)
        assert(ok)
        append(&proc_decl.scope.entities, Entity{
            // TODO: this could be the binding name
            foreign_name = variant.foreign_name,
            name         = variant.name,
            token        = param.token,
        })

        stack->push(param)
    }

    for !allow(.Semicolon) {
        stmt, handled_by_stack := parse_statement()

        if !handled_by_stack {
            append(&proc_decl.body, stmt)
        }
    }

    if len(ep.results) != len(stack.data) {
        parsing_error(
            name_token.pos,
            "number of results for proc {} does not match the signature", ent.name,
        )
    }

    if len(ep.results) > 0 {
        results := make([dynamic]^Ast)
        defer delete(results)

        #reverse for result, index in ep.results {
            value := stack->pop()

            if !types_equal(result.type, value.type) {
                parsing_error(
                    name_token.pos,
                    "unmatched type of data in the stack. Expected {}, got {}",
                    type_to_string(result.type), type_to_string(value.type),
                )
            }

            inject_at(&results, 0, value)
        }

        proc_decl.results = slice.clone(results[:])

        return_node := create_node()
        return_node.variant = Ast_Return{
            params = proc_decl.results,
        }
        append(&proc_decl.body, return_node)
    }

    node.variant = proc_decl
    parser.proc_scope = nil
    pop_scope()
    stack->clear()

    return node
}

parse_variable_decl :: proc(token: Token) -> ^Ast {
    is_global := parser.curr_scope == parser.global_scope
    name_token := expect(.Word)
    name_str := name_token.text
    stack_copy := slice.clone(stack.data[:], context.temp_allocator)
    body := make([dynamic]^Ast)
    defer delete(body)

    if allow(.Word) {
        maybe_type_token := parser.prev_token
        maybe_type := type_from_string(maybe_type_token.text)

        if maybe_type == nil {
            stmt, _ := parse_identifier_statement(maybe_type_token)

            if stmt != nil {
                append(&body, stmt)
            }
        }
    }

    for !allow(.Semicolon) {
        stmt, _ := parse_statement()

        if stmt != nil {
            append(&body, stmt)
        }
    }

    value_node: ^Ast

    if len(body) == 1 {
        value_node = pop(&body)
        value_node.pushed_to_stack = false
    } else {
        value_node = stack->pop()
    }

    name_node := create_node()
    name_node.type = value_node.type
    name_node.variant = Ast_Identifier{
        foreign_name = create_foreign_name(name_token.filename, name_str),
    }

    main_node := create_node()
    main_node.variant = Ast_Variable_Decl{
        is_global = is_global,
        name      = name_node,
        value     = value_node,
    }

    // NOTE: This validation is here to follow the C standard that only
    // known compile-time constants can be used in global variables...
    // TODO: Fix this by making variables smarter for Stanczyk
    if is_global {
        if _, ok := value_node.variant.(Ast_Literal); !ok {
            parsing_error(
                value_node.token.pos,
                "only compile-time known constants can be used in global variable initialization",
            )
        }
    }

    add_entity(Entity{name = name_str, token = name_token, variant = Entity_Variable{name_node}})
    delete(stack.data)
    stack.data = slice.clone_to_dynamic(stack_copy)

    return main_node
}

parse_arithmetic_statement :: proc(token: Token) -> (node: ^Ast, handled: bool) {
    node = create_node()
    b, a := stack->pop(), stack->pop()

    if !types_equal(a.type, b.type) {
        parsing_error(
            token.pos, "mismatched type in arithmetic operation {0}({1}) {2} {3}({4})",
            type_to_string(a.type), value_to_string(a.value), token.text,
            type_to_string(b.type), value_to_string(b.value),
        )
    }

    if !type_is_basic(a.type, .Float) && !type_is_basic(a.type, .Int) && !type_is_basic(a.type, .Uint) {
        parsing_error(
            token.pos, "cannot do arithmetic operation on {}",
            type_to_string(a.type),
        )
    }

    a_value, a_ok := a.variant.(Ast_Literal)
    b_value, b_ok := b.variant.(Ast_Literal)
    parsing_on_literals := a_ok && b_ok

    if parsing_on_literals {
        #partial switch v in a.value {
            case i64: {
                #partial switch token.kind {
                    case .Plus:    node.value = v + b.value.(i64)
                    case .Minus:   node.value = v - b.value.(i64)
                    case .Star:    node.value = v * b.value.(i64)
                    case .Slash:   node.value = v / b.value.(i64)
                    case .Percent: node.value = v % b.value.(i64)
                }
            }
            case f64: {
                #partial switch token.kind {
                    case .Plus:    node.value = v + b.value.(f64)
                    case .Minus:   node.value = v - b.value.(f64)
                    case .Star:    node.value = v * b.value.(f64)
                    case .Slash:   node.value = v / b.value.(f64)
                    case .Percent: node.value = f64(i64(v) % i64(b.value.(f64)))
                }
            }
            case u64: {
                #partial switch token.kind {
                    case .Plus:    node.value = v + b.value.(u64)
                    case .Minus:   node.value = v - b.value.(u64)
                    case .Star:    node.value = v * b.value.(u64)
                    case .Slash:   node.value = v / b.value.(u64)
                    case .Percent: node.value = v % b.value.(u64)
                }
            }
        }

        node.type = a.type
        node.variant = Ast_Literal{}
        stack->push(node)

        return nil, true
    } else {
        name_node := create_node()
        name_node.type = a.type
        name_node.variant = Ast_Identifier{
            foreign_name = create_local_name(),
        }
        node.type = a.type
        node.pushed_to_stack = true
        node.variant = Ast_Binary{
            name     = name_node,
            left     = a,
            right    = b,
            operator = token.text,
        }

        stack->push(name_node)

        return node, false
    }
}

parse_literal_statement :: proc(token: Token) -> (handled: bool) {
    node := create_node()
    node.variant = Ast_Literal{}

    #partial switch token.kind {
        case .Bool_Literal: {
            node.type = parser.known_types["bool"]
            node.value = token.text == "true"
        }
        case .Byte_Literal: {
            node.type = parser.known_types["byte"]
            node.value = token.text
        }
        case .Cstring_Literal: {
            node.type = parser.known_types["cstring"]
            node.value = token.text
        }
        case .Float_Literal: {
            value, ok := strconv.parse_f64(token.text)
            assert(ok)
            node.type = parser.known_types["float"]
            node.value = value
        }
        case .Int_Literal: {
            value, ok := strconv.parse_i64_of_base(token.text, 10)
            assert(ok)
            node.type = parser.known_types["int"]
            node.value = value
        }
        case .String_Literal: {
            node.type = parser.known_types["string"]
            node.value = token.text
        }
        case .Uint_Literal: {
            value, ok := strconv.parse_u64_of_base(token.text, 10)
            assert(ok)
            node.type = parser.known_types["uint"]
            node.value = value
        }
    }

    stack->push(node)
    handled = true

    return
}

parse_identifier_statement :: proc(token: Token) -> (node: ^Ast, handled: bool) {
    ent := find_entity(token.text)

    switch v in ent.variant {
    case Entity_Binding:
    case Entity_Constant:
        stack->push(v.value)
        return nil, true
    case Entity_Procedure:
        node = create_node()
        params := make([dynamic]^Ast)
        defer delete(params)

        #reverse for expected in v.params {
            value := stack->pop()

            if !type_is_any(expected.type) && !types_equal(expected.type, value.type) {
                parsing_error(
                    token.pos,
                    "wrong type of argument while calling {}. Expecting {} but got {}",
                    ent.name, type_to_string(expected.type), type_to_string(value.type),
                )
            }

            inject_at(&params, 0, value)
        }

        if len(v.results) == 0 {
            // no results
            node.variant = Ast_Proc_Call{
                foreign_name = ent.foreign_name,
                params       = slice.clone(params[:]),
            }
        } else {
            result_name := create_local_name()
            name_node := create_node()
            name_node.variant = Ast_Identifier{
                foreign_name = result_name,
            }

            value_node := create_node()
            value_node.variant = Ast_Proc_Call{
                foreign_name = ent.foreign_name,
                params       = slice.clone(params[:]),
            }

            node.variant = Ast_Result_Decl{
                types  = v.results[:],
                name   = name_node,
                value  = value_node,
            }

            // In order to minimize the amount of code generated, we
            // only store the result into one value of the output
            // stack. If there are multiple results, we will pack them
            // into a struct, but the Stanczyk compilation stack will
            // keep reference to all of the fields of that
            // struct. Now, if it's just a single result we store the
            // variable with that type, as we don't need to produce a
            // struct for it.
            if len(v.results) == 1 {
                name_node.type = v.results[0].type
                stack->push(name_node)
            } else {
                for result, index in v.results {
                    stack_value_node := create_node()
                    stack_value_node.type = result.type
                    stack_value_node.variant = Ast_Identifier{
                        foreign_name = fmt.aprintf(
                            "{}.{}{}", result_name, GENERIC_STRUCT_FIELD_NAME, index,
                        ),
                    }
                    stack->push(stack_value_node)
                }
            }
        }

        return node, false
    case Entity_Type:
    case Entity_Variable:
        stack->push(v.value)
        return nil, true
    }

    return nil, false
}

parse_statement :: proc() -> (node: ^Ast, stack_op_done: bool) {
    is_global := parser.curr_scope == parser.global_scope
    token := next()

    switch token.kind {
    case .Binary_Literal:  unimplemented()
    case .Bool_Literal:    stack_op_done = parse_literal_statement(token)
    case .Byte_Literal:    stack_op_done = parse_literal_statement(token)
    case .Cstring_Literal: stack_op_done = parse_literal_statement(token)
    case .Float_Literal:   stack_op_done = parse_literal_statement(token)
    case .Hex_Literal:     unimplemented()
    case .Int_Literal:     stack_op_done = parse_literal_statement(token)
    case .Octal_Literal:   unimplemented()
    case .String_Literal:  stack_op_done = parse_literal_statement(token)
    case .Uint_Literal:    stack_op_done = parse_literal_statement(token)

    case .Plus:    node, stack_op_done = parse_arithmetic_statement(token)
    case .Minus:   node, stack_op_done = parse_arithmetic_statement(token)
    case .Star:    node, stack_op_done = parse_arithmetic_statement(token)
    case .Slash:   node, stack_op_done = parse_arithmetic_statement(token)
    case .Percent: node, stack_op_done = parse_arithmetic_statement(token)

    case .Const:
        register_const()
        stack_op_done = true
    case .Proc: node = parse_proc_decl(token)
    case .Var:  node = parse_variable_decl(token)
    case .Word: node, stack_op_done = parse_identifier_statement(token)

    case .Drop:
        stack->pop()
        stack_op_done = true
    case .Dup:
        a := stack->pop()
        stack->push(a)
        stack->push(a)
        stack_op_done = true
    case .Dup_Star:
        b, a := stack->pop(), stack->pop()
        stack->push(a)
        stack->push(a)
        stack->push(b)
        stack_op_done = true
    case .Nip:
        b, a := stack->pop(), stack->pop()
        stack->push(b)
        stack_op_done = true
    case .Over:
        b, a := stack->pop(), stack->pop()
        stack->push(a)
        stack->push(b)
        stack->push(a)
        stack_op_done = true
    case .Rot:
        c, b, a := stack->pop(), stack->pop(), stack->pop()
        stack->push(b)
        stack->push(c)
        stack->push(a)
        stack_op_done = true
    case .Rot_Star:
        c, b, a := stack->pop(), stack->pop(), stack->pop()
        stack->push(c)
        stack->push(a)
        stack->push(b)
        stack_op_done = true
    case .Swap:
        b, a := stack->pop(), stack->pop()
        stack->push(b)
        stack->push(a)
        stack_op_done = true
    case .Take:
        // Nothing really, just a helpful word to know we're looking for the last element in the stack
        stack_op_done = true
    case .Tuck:
        b, a := stack->pop(), stack->pop()
        stack->push(b)
        stack->push(a)
        stack->push(b)
        stack_op_done = true

    case .Using, .Foreign:
        // No need to do anything here, just skipping
        for !allow(.Semicolon) { next() }
        return parse_statement()

    case .Semicolon:      compiler_bug("forgot to consume the semicolon on a previous statement")
    case .Invalid:        compiler_bug("invalid end of file")
    case .EOF:            unexpected_end_of_file()
    case .Dash_Dash_Dash: compiler_bug("invalid ---")

    case .Like: unimplemented()
    case .Brace_Left: unimplemented()
    case .Brace_Right: unimplemented()
    case .Bracket_Left: unimplemented()
    case .Bracket_Right: unimplemented()
    case .Paren_Left: unimplemented()
    case .Paren_Right: unimplemented()
    case .As: unimplemented()
    case .Type: unimplemented()
    case .Builtin: unimplemented()
    case .Ampersand: unimplemented()
    case .Hat: unimplemented()
    case .Let: unimplemented()
    case .In: unimplemented()
    case .End: unimplemented()
    case .Case: unimplemented()
    case .Else: unimplemented()
    case .Fi: unimplemented()
    case .If: unimplemented()
    case .For: unimplemented()
    case .For_Star: unimplemented()
    case .Loop: unimplemented()
    case .Leave: unimplemented()
    case .Get_Byte: unimplemented()
    case .Set: unimplemented()
    case .Set_Star: unimplemented()
    case .Set_Byte: unimplemented()
    case .Equal: unimplemented()
    case .Greater_Equal: unimplemented()
    case .Greater_Than: unimplemented()
    case .Less_Equal: unimplemented()
    case .Less_Than: unimplemented()
    case .Not_Equal: unimplemented()
    case .Greater_Than_Auto: unimplemented()
    case .Greater_Equal_Auto: unimplemented()
    case .Less_Than_Auto: unimplemented()
    case .Less_Equal_Auto: unimplemented()
    }

    fmt.assertf(stack_op_done && node == nil || !stack_op_done && node != nil, "{}", token)
    return
}

parse :: proc() {
    parser = new(Parser)

    parser.global_scope = push_scope(.Global)

    parser.known_types = make(map[string]^Type)
    parser.known_types["any"]     = new_clone(Type{size = 8, variant = Type_Any{}})
    parser.known_types["bool"]    = new_clone(Type{size = 1, variant = Type_Basic{.Bool}})
    parser.known_types["byte"]    = new_clone(Type{size = 1, variant = Type_Basic{.Byte}})
    parser.known_types["cstring"] = new_clone(Type{size = 8, variant = Type_Basic{.Cstring}})
    parser.known_types["float"]   = new_clone(Type{size = 8, variant = Type_Basic{.Float}})
    parser.known_types["int"]     = new_clone(Type{size = 8, variant = Type_Basic{.Int}})
    parser.known_types["string"]  = new_clone(Type{size = 8, variant = Type_Basic{.String}})
    parser.known_types["uint"]    = new_clone(Type{size = 8, variant = Type_Basic{.Uint}})

    stack.data = make([dynamic]^Ast, 0, 3)

    stack.clear = proc(s: ^Stack) {
        clear(&s.data)
    }

    stack.pop = proc(s: ^Stack) -> ^Ast {
        assert(len(s.data) > 0)
        v := pop(&s.data)
        return v
    }

    stack.push = proc(s: ^Stack, v: ^Ast) {
        append(&s.data, v)
    }

    for source in source_files {
        tokenizer_init(&parser.tokenizer, source)
        next()

        for !allow(.EOF) {
            token := next()

            #partial switch token.kind {
                case .Const: {
                    register_const()
                }

                case .Var: {
                    append(&parser.program, parse_variable_decl(parser.prev_token))
                }

                case .Foreign, .Proc: {
                    is_foreign := token.kind == .Foreign

                    if is_foreign {
                        expect(.Proc)
                    }

                    register_proc(is_foreign)
                    scope_level := 1

                    body_loop: for {
                        token2 := next()

                        #partial switch token2.kind {
                            case .Const: scope_level += 1
                            case .Var:   scope_level += 1
                            case .Semicolon: {
                                scope_level -= 1

                                if scope_level == 0 {
                                    break body_loop
                                }
                            }
                        }
                    }
                }

                case .Using: {
                    for !allow(.Semicolon) {
                        token2 := next()

                        if token2.kind == .Word {
                            collection_dir := "base"
                            lib_name := token2.text

                            if strings.contains(lib_name, ".") {
                                collection_dir, _, lib_name = strings.partition(lib_name, ".")
                            }

                            ok := load_from_standard_libs(collection_dir, lib_name)

                            if !ok {
                                parsing_error(
                                    token2.pos,
                                    "failed to load library from {}.{}",
                                    collection_dir, lib_name,
                                )
                            }
                        } else {
                            parsing_error(
                                token2.pos,
                                "expected words in 'using' statement, got {}",
                                token_to_string(token2),
                            )
                        }
                    }
                }
            }
        }
    }

    for source in source_files {
        tokenizer_init(&parser.tokenizer, source)
        next()

        for !allow(.EOF) {
            token := next()

            if token.kind == .Foreign {
                for !allow(.Semicolon) { next() }
            }

            if token.kind == .Proc {
                append(&parser.program, parse_proc_decl(token))
            }
        }
    }
}
