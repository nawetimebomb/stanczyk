package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strconv"
import "core:strings"

Arity :: distinct [dynamic]^Type

Code :: distinct [dynamic]Bytecode

Function :: struct {
    entity: ^Entity,
    parent: ^Function,

    binds_count: int,
    called:      bool,
    errored:     bool,
    local_ip:    uint,
    local_mem:   uint,

    code:      Code,
    stack:     Stack,
}

Scope_Kind :: enum u8 {
    Invalid,
    Global,
    Procedure,
    If, If_Else, Let,
    Loop,
}

Entities :: distinct [dynamic]Entity

// Scope :: struct {
//     kind:   Scope_Kind,
//     token:  Token,
//     parent: ^Scope,
//     level:  int,
//     autoincrement: bool,
//     autoincrement_value: int,

//     start_op: ^Bytecode,

//     entities:     Entities,
//     stack_copies: [dynamic][]^Type,

//     validation_at_end: enum {
//         Skip,
//         Stack_Is_Unchanged,
//         Stack_Match_Between,
//     },
// }

Checker :: struct {
    curr_function: ^Function,
    curr_scope:    ^Scope,

    basic_types: [Type_Basic_Kind]^Type,

    prev_token: Token,
    curr_token: Token,
    tokenizer:  Tokenizer,

    errors: [dynamic]string,
}

gscope: ^Scope
checker: ^Checker

functions        := make([dynamic]Function)
C_functions      := make([dynamic]string)
strings_table    := map[string]int{}

// // Compilation error are not fatal, but will skip function parsing/compilation
// // and save the error to the Checker. Errors added to the checker will be reported
// // at the end of compilation.
// compilation_error :: proc(f: ^Function, format: string, args: ..any) {
//     pos := f.entity.pos

//     fmt.assertf(
//         checker.curr_function != nil,
//         "compilation error can only happen when compiling a function content",
//     )

//     eb := strings.builder_make()
//     fmt.sbprintf(&eb, "%s(%d:%d) compilation error in function {}: ",
//                  pos.filename, pos.line, pos.column, f.entity.name)
//     fmt.sbprintf(&eb, format, ..args)
//     fmt.sbprint(&eb, "\n")
//     append(&checker.errors, strings.to_string(eb))
//     f.errored = true
// }

// // Parsing errors are fatal. We can't really know if the code following this
// // error can be parsed correctly, so we need to forcibly exit.
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

// // Stack errors are fatal. We can't continue compiling because this would mean that
// // all the following functions are going to also fail for the same reason.
// stack_error :: proc(pos: Position, format: string, args: ..any) {
//     // TODO: Fail when stack doesn't match, when stack is missing, and report position of the error and who called it.
// }

unexpected_end_of_file :: proc() {
    parsing_error(parser.prev_token.pos, "unexpected end of file")
}

compiler_bug :: proc(details: string = "not specified by the compiler developer") {
    parsing_error(parser.prev_token.pos, "COMPILER BUG: This is an error on the compiler, not on the Stańczyk code.\nThe root cause for this might be: %s", details)
}

// push_string :: proc(v: string) -> int {
//     id, ok := strings_table[v]
//     if !ok {
//         id = len(strings_table)
//         strings_table[v] = id
//     }
//     return id
// }

// add_global_bool_constant :: proc(name: string, value: bool) {
//     append(&gscope.entities, Entity{
//         is_global = true,
//         name = name,
//         variant = Entity_Constant{
//             type = checker.basic_types[.Bool],
//             value = Push_Bool{value},
//         },
//     })
// }

// add_global_string_constant :: proc(name: string, value: string) {
//     append(&gscope.entities, Entity{
//         is_global = true,
//         name = name,
//         variant = Entity_Constant{
//             type = checker.basic_types[.String],
//             value = Push_String{push_string(value)},
//         },
//     })
// }

// add_type :: proc(name: string, type: ^Type) {
//     append(&checker.curr_scope.entities, Entity{
//         is_global = true,
//         name = name,
//         variant = Entity_Type{
//             type = type,
//         },
//     })
// }

// allow :: proc(kind: Token_Kind) -> bool {
//     if checker.curr_token.kind == kind {
//         next()
//         return true
//     }
//     return false
// }

// emit_global :: proc(token: Token, v: Bytecode_Variant) {
//     append(&gen.global_code, Bytecode{
//         address = get_global_address(),
//         pos = token.pos,
//         variant = v,
//     })
// }

// emit :: proc(f: ^Function, token: Token, v: Bytecode_Variant) -> ^Bytecode {
//     append(&f.code, Bytecode{
//         address = get_local_address(f),
//         pos = token.pos,
//         variant = v,
//     })
//     return &f.code[len(f.code) - 1]
// }

// expect :: proc(kind: Token_Kind) -> Token {
//     token := next()

//     if token.kind != kind {
//         parsing_error(
//             token.pos,
//             "expected %q, got %s",
//             token_string_table[kind],
//             token_to_string(token),
//         )
//     }

//     return token
// }

// next :: proc() -> Token {
//     token, err := get_next_token(&checker.tokenizer)
//     if err != nil && token.kind != .EOF {
//         parsing_error(token.pos, "found invalid token: %v", err)
//     }
//     checker.prev_token, checker.curr_token = checker.curr_token, token
//     return checker.prev_token
// }

// peek :: proc() -> Token_Kind {
//     return checker.curr_token.kind
// }

// compile :: proc() {
//     checker = &Checker{}
//     init_generator()
//     init_everything()

//     for source in source_files {
//         tokenizer_init(&checker.tokenizer, source)
//         next()

//         first_loop: for {
//             token := next()

//             #partial switch token.kind {
//                 case .Using: parse_using()
//                 case .Const: declare_const()
//                 case .Var: declare_var()
//                 case .Type: declare_type()
//                 case .Builtin: {
//                     expect(.Fn)
//                     declare_func(.Builtin)
//                     expect(.Dash_Dash_Dash)
//                 }
//                 case .Foreign: {
//                     expect(.Fn)
//                     declare_func(.Foreign)
//                     expect(.Dash_Dash_Dash)
//                 }
//                 case .Fn: {
//                     declare_func()
//                     scope_level := 1

//                     body_loop: for {
//                         token := next()

//                         #partial switch token.kind {
//                             case .Const: scope_level += 1
//                             case .Var: scope_level += 1
//                             case .Fn: scope_level += 1
//                             case .EOF: unexpected_end_of_file()
//                             case .Semicolon: {
//                                 scope_level -= 1
//                                 if scope_level == 0 { break body_loop }
//                             }
//                         }
//                     }
//                 }
//                 case .EOF: break first_loop
//                 case: parsing_error(
//                     token.pos, "unexpected token of type %s", token_to_string(token),
//                 )
//             }
//         }
//     }

//     for source in source_files {
//         tokenizer_init(&checker.tokenizer, source)
//         next()

//         parsing_loop: for {
//             token := next()

//             #partial switch token.kind {
//                 case .EOF: break parsing_loop
//                 case .Builtin, .Foreign: {
//                     skip_to_end: for {
//                         if next().kind == .Dash_Dash_Dash {
//                             break skip_to_end
//                         }
//                     }
//                 }
//                 case .Fn: {
//                     name_token := expect(.Word)
//                     parsing_entity: ^Entity

//                     // Searching the function by its token
//                     for &other in gscope.entities {
//                         if other.token == name_token {
//                             parsing_entity = &other
//                             break
//                         }
//                     }

//                     if parsing_entity == nil {
//                         parsing_error(
//                             name_token.pos,
//                             "compiler error failed to find Function entity",
//                         )
//                     }

//                     if allow(.Paren_Left) {
//                         skip_to_body: for {
//                             if next().kind == .Paren_Right {
//                                 break skip_to_body
//                             }
//                         }
//                     }

//                     parse_function(parsing_entity)
//                 }
//             }
//         }
//     }

//     if len(checker.errors) > 0 {
//         for err in checker.errors {
//             fmt.eprintln(err)
//         }

//         os.exit(1)
//     }

//     gen_program()
//     deinit_everything()
// }

// init_everything :: proc() {
//     gscope = push_scope(Token{}, .Global)

//     checker.basic_types[.Bool]   = new_clone(Type{size = 1, variant = Type_Basic{.Bool}}, context.temp_allocator)
//     checker.basic_types[.Byte]   = new_clone(Type{size = 1, variant = Type_Basic{.Byte}}, context.temp_allocator)
//     checker.basic_types[.Int]    = new_clone(Type{size = 8, variant = Type_Basic{.Int}}, context.temp_allocator)
//     checker.basic_types[.String] = new_clone(Type{size = 8, variant = Type_Basic{.String}}, context.temp_allocator)

//     add_type("any", new_clone(Type{size = 8, variant = Type_Any{}}, context.temp_allocator))
//     add_type("bool", checker.basic_types[.Bool])
//     add_type("byte", checker.basic_types[.Byte])
//     add_type("int", checker.basic_types[.Int])
//     add_type("string", checker.basic_types[.String])

//     // Add compiler defined constants
//     add_global_bool_constant("OS_DARWIN",  ODIN_OS == .Darwin)
//     add_global_bool_constant("OS_LINUX",   ODIN_OS == .Linux)
//     add_global_bool_constant("OS_WINDOWS", ODIN_OS == .Windows)
//     add_global_bool_constant("SK_DEBUG",   debug_switch_enabled)

//     add_global_string_constant("SK_VERSION", COMPILER_VERSION)
// }

// deinit_everything :: proc() {
//     assert(checker.curr_scope.parent == nil)
//     delete_scope(checker.curr_scope)
//     assert(checker.curr_function == nil)

//     for &f in functions {
//         f.stack->free()
//         delete(f.code)
//     }

//     delete(gen.global_code)
//     delete(strings_table)
//     delete(C_functions)
// }

// find_entity :: proc(f: ^Function, token: Token) -> Entity {
//     possible_matches := make(Entities, context.temp_allocator)
//     name := token.text
//     test_scope := checker.curr_scope
//     found := false

//     for !found && test_scope != nil {
//         for check in test_scope.entities {
//             if check.name == name {
//                 append(&possible_matches, check)
//                 found = true
//             }
//         }

//         if !found { test_scope = test_scope.parent }
//     }

//     switch len(possible_matches) {
//     case 0: // Nothing found, so we error out
//         parsing_error(token.pos, "undefined word '%s'", name)
//     case 1: // Just one definition found, return
//         return possible_matches[0]
//     case :
//         // Technically we should handle this error by only allowing certain
//         // types of entities to be return. In this case, when f = nil, we
//         // don't want stack manipulation to happen, because we're just looking
//         // for constants or variables.
//         assert(f != nil)

//         // Multiple entities found, need to figure out which one it is.
//         // The good thing is that now we know this is a function, because
//         // other types of values are not polymorphic.
//         // We track the possible result by prioritizing the number of inputs
//         // that the function can receive, but we also check for its arity.
//         Match_Stats :: struct { entity: Entity, exact_number_inputs: bool, }
//         matches := make([dynamic]Match_Stats, 0, 1, context.temp_allocator)

//         for other in possible_matches {
//             test := other.variant.(Entity_Function)

//             if len(f.stack.v) >= len(test.inputs) {
//                 stack_copy := slice.clone(f.stack.v[:])
//                 defer delete(stack_copy)
//                 slice.reverse(stack_copy[:])
//                 sim_test_stack := stack_copy[:len(test.inputs)]
//                 func_test_stack := make([dynamic]^Type, context.temp_allocator)
//                 defer delete(func_test_stack)

//                 for input in test.inputs {
//                     append(&func_test_stack, input)
//                 }

//                 if slice.equal(sim_test_stack, func_test_stack[:]) {
//                     append(&matches, Match_Stats{
//                         entity = other,
//                         exact_number_inputs = len(f.stack.v) == len(test.inputs),
//                     })
//                 }
//             }
//         }

//         if len(matches) == 1 {
//             // Found and there's only one that makes sense, so return it.
//             return matches[0].entity
//         } else {
//             // Prioritize the one that has exact match of inputs.
//             // This makes it so we can have a function with arity of one and another
//             // with arity of more than one, but one of the types matches.
//             for m in matches {
//                 if m.exact_number_inputs {
//                     return m.entity
//                 }
//             }
//         }

//         report_posible_matches :: proc(possible_matches: []Entity) -> string {
//             if len(possible_matches) == 0 {
//                 return ""
//             }
//             builder := strings.builder_make(context.temp_allocator)
//             strings.write_string(&builder, "\nPossible matches:\n")

//             for e in possible_matches {
//                 if ef, ok := e.variant.(Entity_Function); ok {
//                     fmt.sbprintf(&builder, "\t{0} (", e.name)
//                     for input, index in ef.inputs {
//                         if len(ef.outputs) == 0 && index == len(ef.inputs) - 1 {
//                             fmt.sbprintf(&builder, "{})", type_to_string(input))
//                         } else {
//                             fmt.sbprintf(&builder, "{} ", type_to_string(input))
//                         }
//                     }
//                     if len(ef.outputs) > 0 {
//                         fmt.sbprint(&builder, "--- ")
//                         for output, index in ef.outputs {
//                             if index == len(ef.outputs) - 1 {
//                                 fmt.sbprintf(&builder, "{})", type_to_string(output))
//                             } else {
//                                 fmt.sbprintf(&builder, "{} ", type_to_string(output))
//                             }
//                         }
//                     }
//                     fmt.sbprint(&builder, "\n")
//                 }
//             }

//             return strings.to_string(builder)
//         }

//         // Unfortunately we couldn't find a reliable result, so we error out.
//         parsing_error(
//             token.pos,
//             "unable to find matching function of name '{}' with stack {}{}",
//             token.text,
//             stack_prettyprint("{}", ..f.stack.v[:]),
//             report_posible_matches(possible_matches[:]),
//         )
//     }

//     return Entity{}
// }

// push_function :: proc(entity: ^Entity) -> ^Scope {
//     // TODO: This only support global functions, which I think it's fine, but if at some point
//     // we want to support functions inside another function scope, we need to allow it here.
//     for &f in functions {
//         if f.entity.token == entity.token {
//             checker.curr_function = &f
//             break
//         }
//     }

//     fmt.assertf(checker.curr_function != nil, "missing {}", entity.name)

//     return push_scope(entity.token, .Function)
// }

// pop_function :: proc() {
//     assert(checker.curr_function != nil)
//     pop_scope()
//     checker.curr_function = checker.curr_function.parent
// }

// push_scope :: proc(t: Token, k: Scope_Kind) -> ^Scope {
//     checker.curr_scope = new_clone(Scope{
//         token = t,
//         entities = make(Entities, context.temp_allocator),
//         parent = checker.curr_scope,
//         level = checker.curr_scope == nil ? 0 : checker.curr_scope.level + 1,
//         kind = k,
//     })
//     return checker.curr_scope
// }

// pop_scope :: proc() {
//     assert(checker.curr_scope != nil)
//     assert(checker.curr_function != nil)

//     switch checker.curr_scope.validation_at_end {
//     case .Skip:
//         // Do nothing
//     case .Stack_Is_Unchanged:
//         // The stack hasn't changed in length and types. It only supports one stack copy
//         stack_copies := &checker.curr_scope.stack_copies
//         assert(len(stack_copies) > 0)

//         if len(stack_copies) != 1 {
//             for A, index in checker.curr_function.stack.v {
//                 B := stack_copies[0][index]
//                 if !types_equal(A, B) {
//                     parsing_error(
//                         checker.curr_scope.token,
//                         "stack changes not allowed on this scope block\n\tBefore: {}\n\tAfter: {}",
//                         stack_copies[0], checker.curr_function.stack.v,
//                     )
//                 }
//             }
//         }
//     case .Stack_Match_Between:
//         // The stack has to have the same result between its branching values
//         stack_copies := &checker.curr_scope.stack_copies

//         for i in 0..<len(stack_copies) - 1 {
//             for _, j in stack_copies[i] {
//                 A, B := stack_copies[i][j], stack_copies[i + 1][j]

//                 if !types_equal(A, B) {
//                     parsing_error(
//                         checker.curr_scope.token,
//                         "different stack effects between scopes not allowed",
//                     )
//                 }
//             }
//         }
//     }

//     for item in checker.curr_scope.stack_copies {
//         delete(item)
//     }

//     // Realign bindings after the scope is closed
//     binds_count_in_scope := 0

//     for e in checker.curr_scope.entities {
//         if _, ok := e.variant.(Entity_Binding); ok {
//             binds_count_in_scope += 1
//         }
//     }

//     update_scope := checker.curr_scope.parent

//     for update_scope != nil {
//         for &e in update_scope.entities {
//             #partial switch &v in e.variant {
//                 case Entity_Binding: v.index -= binds_count_in_scope
//             }
//         }

//         update_scope = update_scope.parent
//     }

//     old_scope := checker.curr_scope
//     checker.curr_scope = old_scope.parent
//     delete_scope(old_scope)
// }

// delete_scope :: proc(s: ^Scope) {
//     for &e in s.entities {
//         switch v in e.variant {
//         case Entity_Binding:
//         case Entity_Constant:
//         case Entity_Function:
//             delete(v.inputs)
//             delete(v.outputs)
//         case Entity_Procedure:
//         case Entity_Type:
//         case Entity_Variable:
//         }
//     }

//     delete(s.entities)
//     delete(s.stack_copies)
//     free(s)
// }

// create_stack_snapshot :: proc(f: ^Function, s: ^Scope) {
//     append(&s.stack_copies, slice.clone(f.stack.v[:]))
// }

// refresh_stack_snapshot :: proc(f: ^Function, s: ^Scope) {
//     delete(pop(&s.stack_copies))
//     create_stack_snapshot(f, s)
// }

// declare_type :: proc() {
//     name_token := expect(.Word)
//     name := name_token.text
//     et := Entity_Type{}
//     f := checker.curr_function
//     entities := &checker.curr_scope.entities

//     value_name_token := expect(.Word)
//     expect(.Semicolon)

//     if name_token.text == value_name_token.text {
//         // Do nothing, this was already defined on the compiler
//         return
//     }

//     entity := find_entity(f, value_name_token)

//     #partial switch v in entity.variant {
//         case Entity_Type: {
//             et.type = v.type
//         }
//         case: parsing_error(value_name_token, "'{}' not a known type", value_name_token.text)
//     }

//     append(entities, Entity{
//         pos = name_token.pos,
//         token = name_token,
//         address = 0,
//         name = name_token.text,
//         is_global = f == nil,
//         variant = et,
//     })
// }

// declare_const :: proc() {
//     name_token := expect(.Word)
//     name := name_token.text
//     f := checker.curr_function
//     ec := Entity_Constant{}
//     entities := &checker.curr_scope.entities
//     inferred_type: ^Type
//     temp_stack := make([dynamic]int, context.temp_allocator)
//     defer delete(temp_stack)

//     decl_body: for {
//         t := next()

//         #partial switch t.kind {
//             case .EOF: unexpected_end_of_file()
//             case .Semicolon: break decl_body
//             case .Word: {
//                 if name == t.text {
//                     if len(temp_stack) > 0 {
//                         parsing_error(t, "unexpected values in supposed compiler-defined constant {}", name)
//                     }

//                     // Check if the compiler-defined constant exists
//                     for e in gscope.entities {
//                         if e.name == name {
//                             expect(.Semicolon)
//                             return
//                         }
//                     }

//                     parsing_error(t, "constant {} is not actually compiler-defined", name)
//                 } else {
//                     entity := find_entity(f, t)

//                     switch v in entity.variant {
//                     case Entity_Binding: unimplemented()
//                     case Entity_Constant:
//                         if inferred_type != nil && inferred_type != v.type {
//                             parsing_error(
//                                 t,
//                                 "type mismatch in constant {}.\n\tExpected: {}\n\tGot: {}",
//                                 name, type_to_string(inferred_type), type_to_string(v.type),
//                             )
//                         }

//                         inferred_type = v.type
//                         switch {
//                         case types_equal(v.type, checker.basic_types[.Int]):
//                             value := v.value.(Push_Int).val
//                             append(&temp_stack, value)
//                         case :
//                             ec.value = v.value
//                             expect(.Semicolon)
//                             break decl_body
//                         }
//                     case Entity_Function: unimplemented()
//                     case Entity_Type:
//                         ec.type = v.type
//                     case Entity_Variable: unimplemented()
//                     }
//                 }
//             }
//             case .Bool_Literal: {
//                 ec.value = Push_Bool{t.text == "true"}
//                 inferred_type = checker.basic_types[.Bool]
//                 expect(.Semicolon)
//                 break decl_body
//             }
//             case .Integer_Literal: {
//                 append(&temp_stack, strconv.atoi(t.text))
//                 int_type := checker.basic_types[.Int]
//                 if inferred_type != nil && !types_equal(inferred_type, int_type) {
//                     parsing_error(t.pos, "constant values in {} can only be of one type.\n\tExpected: {}\n\tGot: {}", name, type_to_string(inferred_type), type_to_string(int_type))
//                 }
//                 inferred_type = int_type
//             }
//             case .String_Literal: {
//                 ec.value = Push_String{push_string(t.text)}
//                 inferred_type = checker.basic_types[.String]
//                 expect(.Semicolon)
//                 break decl_body
//             }
//             case .Plus: {
//                 v2 := pop(&temp_stack)
//                 v1 := pop(&temp_stack)
//                 append(&temp_stack, v1 + v2)
//             }
//             case .Minus: {
//                 v2 := pop(&temp_stack)
//                 v1 := pop(&temp_stack)
//                 append(&temp_stack, v1 - v2)
//             }
//             case .Star: {
//                 v2 := pop(&temp_stack)
//                 v1 := pop(&temp_stack)
//                 append(&temp_stack, v1 * v2)
//             }
//             case .Slash: {
//                 v2 := pop(&temp_stack)
//                 v1 := pop(&temp_stack)
//                 append(&temp_stack, v1 / v2)
//             }
//             case .Percent: {
//                 v2 := pop(&temp_stack)
//                 v1 := pop(&temp_stack)
//                 append(&temp_stack, v1 % v2)
//             }
//         }
//     }

//     if ec.type != nil && !types_equal(ec.type, inferred_type) {
//         parsing_error(name_token, "type '{}' does not match with value of type '{}' in constant '{}'", type_to_string(ec.type), type_to_string(inferred_type), name)
//     }

//     ec.type = inferred_type

//     if len(temp_stack) > 0 {
//         if len(temp_stack) != 1 {
//             compiler_bug()
//         }
//         ec.value = Push_Int{pop(&temp_stack)}
//     }

//     if name == "main" {
//         parsing_error(
//             name_token.pos,
//             "main is a reserved word for the entry point function of the program",
//         )
//     }

//     for other in entities {
//         if other.name == name {
//             parsing_error(
//                 name_token.pos, "redeclaration of '{}' found in {}:{}:{}",
//                 name, other.filename, other.line, other.column,
//             )
//         }
//     }

//     append(entities, Entity{
//         name = name,
//         pos = name_token.pos,
//         token = name_token,
//         variant = ec,
//     })
// }

// declare_var :: proc() {
//     _emit :: proc(t: Token, v: Bytecode_Variant) {
//         // We want this function to emit to global code if it's a global variable
//         // and emit to current function if it's a local scope variable.
//         f := checker.curr_function
//         if f == nil { emit_global(t, v) } else { emit(f, t, v) }
//     }

//     name_token := expect(.Word)
//     name := name_token.text
//     is_global := checker.curr_scope == gscope
//     entities := &checker.curr_scope.entities
//     ev := Entity_Variable{}
//     address: uint

//     inferred_type: ^Type
//     temp_stack := make([dynamic]^Type, context.temp_allocator)
//     defer delete(temp_stack)

//     decl_body: for {
//         t := next()

//         #partial switch t.kind {
//             case .EOF: unexpected_end_of_file()
//             case .Semicolon: break decl_body
//             case .Word: {
//                 entity := find_entity(checker.curr_function, t)

//                 switch v in entity.variant {
//                 case Entity_Binding:
//                     _emit(t, Push_Bound{val = v.index, mutable = v.mutable})
//                     append(&temp_stack, v.type)
//                     if inferred_type != nil && !types_equal(inferred_type, v.type) {
//                         parsing_error(
//                             t, "type mismatch in variable {}.\n\tExpected: {}\n\tGot: {}",
//                             name, type_to_string(inferred_type), type_to_string(v.type),
//                         )
//                     }
//                     inferred_type = v.type
//                 case Entity_Constant:
//                     _emit(t, v.value)
//                     append(&temp_stack, v.type)
//                     if inferred_type != nil && !types_equal(inferred_type, v.type) {
//                         parsing_error(
//                             t, "type mismatch in variable {}.\n\tExpected: {}\n\tGot: {}",
//                             name, type_to_string(inferred_type), type_to_string(v.type),
//                         )
//                     }
//                     inferred_type = v.type
//                 case Entity_Function:
//                     unimplemented()
//                 case Entity_Type:
//                     ev.type = v.type
//                     ev.size = v.type.size
//                 case Entity_Variable:
//                     if entity.is_global {
//                         _emit(t, Push_Var_Global{v.offset, false})
//                     } else {
//                         _emit(t, Push_Var_Local{v.offset, false})
//                     }
//                     append(&temp_stack, v.type)

//                     if inferred_type != nil && !types_equal(inferred_type, v.type) {
//                         parsing_error(
//                             t, "type mismatch in variable {}.\n\tExpected: {}\n\tGot: {}",
//                             name, type_to_string(inferred_type), type_to_string(v.type),
//                         )
//                     }
//                     inferred_type = v.type
//                 }
//             }
//             case .Bool_Literal: {
//                 _emit(t, Push_Bool{t.text == "true"})
//                 inferred_type = checker.basic_types[.Bool]
//                 expect(.Semicolon)
//                 break decl_body
//             }
//             case .Integer_Literal: {
//                 _emit(t, Push_Int{strconv.atoi(t.text)})
//                 int_type := checker.basic_types[.Int]
//                 append(&temp_stack, int_type)
//                 if inferred_type != nil && !types_equal(inferred_type, int_type) {
//                     parsing_error(t.pos, "values in variable {} can only be of one type.\n\tExpected: {}\n\tGot: {}", name, type_to_string(inferred_type), type_to_string(int_type))
//                 }
//                 inferred_type = int_type
//             }
//             case .String_Literal: {
//                 _emit(t, Push_String{push_string(t.text)})
//                 inferred_type = checker.basic_types[.String]
//                 expect(.Semicolon)
//                 break decl_body
//             }
//             case .Plus: {
//                 v2 := pop(&temp_stack)
//                 v1 := pop(&temp_stack)
//                 append(&temp_stack, v1)
//                 _emit(t, Add{})
//             }
//             case .Minus: {
//                 v2 := pop(&temp_stack)
//                 v1 := pop(&temp_stack)
//                 append(&temp_stack, v1)
//                 _emit(t, Substract{})
//             }
//             case .Star: {
//                 v2 := pop(&temp_stack)
//                 v1 := pop(&temp_stack)
//                 append(&temp_stack, v1)
//                 _emit(t, Multiply{})
//             }
//             case .Slash: {
//                 v2 := pop(&temp_stack)
//                 v1 := pop(&temp_stack)
//                 append(&temp_stack, v1)
//                 _emit(t, Divide{})
//             }
//             case .Percent: {
//                 v2 := pop(&temp_stack)
//                 v1 := pop(&temp_stack)
//                 append(&temp_stack, v1)
//                 _emit(t, Modulo{})
//             }
//         }
//     }

//     if ev.type != nil && inferred_type != nil && !types_equal(ev.type, inferred_type) {
//         parsing_error(name_token, "type '{}' does not match with value of type '{}' in variable '{}'", type_to_string(ev.type), type_to_string(inferred_type), name)
//     }

//     if ev.type == nil {
//         ev.type = inferred_type
//         ev.size = ev.type.size
//     }

//     if len(temp_stack) > 1 { compiler_bug() }

//     if is_global {
//         address = get_global_address()
//         ev.offset = gen.global_mem_count
//         gen.global_mem_count += ev.size
//         emit_global(name_token, Declare_Var_Global{
//             offset = ev.offset,
//             kind = ev.type.variant.(Type_Basic).kind,
//             set = inferred_type != nil,
//         })
//     } else {
//         f := checker.curr_function
//         address = get_local_address(f)
//         ev.offset = f.local_mem
//         f.local_mem += ev.size
//         emit(f, name_token, Declare_Var_Local{
//             offset = ev.offset,
//             kind = ev.type.variant.(Type_Basic).kind,
//             set = inferred_type != nil,
//         })
//     }

//     append(entities, Entity{
//         address = address,
//         is_global = is_global,
//         pos = name_token.pos,
//         name = name,
//         variant = ev,
//     })
// }

// declare_func :: proc(kind: enum { Default, Builtin, Foreign } = .Default) {
//     name_token := expect(.Word)
//     name := name_token.text
//     is_foreign := kind == .Foreign
//     is_builtin := kind == .Builtin
//     foreign_name := name
//     address := get_global_address()
//     entities := &checker.curr_scope.entities
//     is_main := false
//     ef := Entity_Function{
//         inputs = make(Arity),
//         outputs = make(Arity),
//     }

//     if is_foreign {
//         if allow(.As) {
//             foreign_name = name
//             name_token = expect(.Word)
//             name = name_token.text
//         }
//     }

//     parse_function_head(&ef)

//     if name == "main" {
//         gen.main_func_address = address
//         is_main = true
//     }

//     for &other in entities {
//         if other.name == name {
//             if is_main {
//                 parsing_error(
//                     name_token.pos, "redeclared main in {}:{}:{}",
//                     other.filename, other.line, other.column,
//                 )
//             }

//             #partial switch &v in other.variant {
//                 case Entity_Function: {
//                     if v.has_any_input || ef.has_any_input {
//                         err_token := v.has_any_input ? other.token : name_token
//                         parsing_error(err_token.pos, "a function with 'any' input exists and it can't be polymorphic")
//                     }

//                     if v.is_parapoly || ef.is_parapoly {
//                         err_token := v.is_parapoly ? other.token : name_token
//                         parsing_error(err_token.pos, "parapoly functions can't be polymorphic")
//                     }

//                     v.is_polymorphic = true
//                     ef.is_polymorphic = true
//                 }
//                 case: parsing_error(
//                     name_token.pos, "{} redeclared at {}:{}:{}",
//                     other.filename, other.line, other.column,
//                 )
//             }
//         }
//     }

//     append(entities, Entity{
//         address = address,
//         is_global = true, // functions are only allowed in global scope
//         is_builtin = is_builtin,
//         is_foreign = is_foreign,
//         name = name,
//         foreign_name = foreign_name,
//         pos = name_token.pos,
//         token = name_token,
//         variant = ef,
//     })

//     if !is_builtin && !is_foreign {
//         // Builtin functions are compiler-defined, so they don't
//         // really create any code, but instead do custom code generation.
//         append(&functions, Function{
//             entity = &entities[len(entities) - 1],
//             called = name == "main",
//             local_ip = 0,
//         })
//     }
// }

// parse_function_head :: proc(ef: ^Entity_Function) {
//     if allow(.Paren_Left) {
//         if !allow(.Paren_Right) {
//             arity := &ef.inputs
//             outputs := false

//             arity_loop: for {
//                 token := next()

//                 #partial switch token.kind {
//                     case .Paren_Right: break arity_loop
//                     case .Dash_Dash_Dash: {
//                         arity = &ef.outputs
//                         outputs = true
//                     }
//                     case .Word: {
//                         found := false

//                         for &e in gscope.entities {
//                             if e.name == token.text {
//                                 if v, ok := e.variant.(Entity_Type); ok {
//                                     found = true
//                                     append(arity, v.type)

//                                     if e.name == "any" {
//                                         ef.has_any_input = true

//                                         if outputs {
//                                             parsing_error(
//                                                 token.pos,
//                                                 "functions can't have 'Any' as outputs",
//                                             )
//                                         }
//                                     }
//                                 }
//                             }
//                         }

//                         if !found {
//                             ef.is_parapoly = true
//                             append(arity, type_string_to_Type(token.text))
//                         }
//                     }
//                     case .Hat: {
//                         type_token := expect(.Word)
//                         T := type_string_to_Type(type_token.text)
//                         append(arity, type_create_pointer(T))
//                     }
//                     case: parsing_error(
//                         token.pos, "unexpected token %s", token_to_string(token),
//                     )
//                 }
//             }
//         }
//     }
// }

// parse_using :: proc() {
//     using_loop: for {
//         t := next()

//         #partial switch t.kind {
//             case .Semicolon: break using_loop
//             case .Word: {
//                 collection_dir := "base"
//                 import_dir := t.text

//                 if strings.contains(import_dir, ".") {
//                     collection_dir, _, import_dir = strings.partition(import_dir, ".")
//                 }

//                 load_files(fmt.tprintf("{}/{}/{}", compiler_dir, collection_dir, import_dir))
//             }
//             case: {
//                 parsing_error(
//                     t.pos,
//                     "expected words in 'using' statement, got {}",
//                     token_string_table[t.kind],
//                 )
//             }
//         }
//     }
// }

// call_foreign_func :: proc(f: ^Function, t: Token, e: Entity) {
//     ef := e.variant.(Entity_Function)

//     #reverse for input in ef.inputs {
//         A := f.stack->pop()

//         if !types_equal(input, A) && !type_is_any(input) {
//             compilation_error(
//                 f, "input mismatch in function {}\n\tExpected: {},\tHave: {}",
//                 t.text, type_to_string(input), type_to_string(A),
//             )
//         }
//     }

//     // Adding the C function to the called callection so it can be
//     // added to the generated code.
//     if !slice.contains(C_functions[:], e.foreign_name) {
//         append(&C_functions, e.foreign_name)
//     }

//     b := emit(f, t, Call_C_Function{
//         name = e.foreign_name,
//         inputs = len(ef.inputs),
//         outputs = len(ef.outputs),
//     })

//     for output in ef.outputs {
//         f.stack->push(output)
//     }
// }

// call_builtin_func :: proc(f: ^Function, t: Token, e: Entity) {
//     ef := e.variant.(Entity_Function)

//     switch e.name {
//         // Handle builtin functions here
//     }
// }

// call_function :: proc(entity: Entity, loc := #caller_location) {
//     f := checker.curr_function
//     ef := entity.variant.(Entity_Function)
//     token := checker.prev_token
//     parapoly_table := make(map[string]^Type, context.temp_allocator)
//     defer delete(parapoly_table)

//     #reverse for input in ef.inputs {
//         A := f.stack->pop()

//         switch {
//         case type_is_polymorphic(input):
//             v, ok := parapoly_table[input.name]

//             if !ok {
//                 parapoly_table[input.name] = A
//                 v = A
//             }

//             if A != v {
//                 compilation_error(
//                     checker.curr_function,
//                     "parapoly of name '{}' means '{}' in this declaration, got '{}'",
//                     input.name, type_to_string(v), type_to_string(A),
//                 )
//             }
//         case !types_equal(input, A) && !type_is_any(input):
//             compilation_error(
//                 checker.curr_function,
//                 "input mismatch in function {}\n\tExpected: {},\tHave: {}",
//                 token.text, input, A,
//             )
//         }
//     }

//     // Mark the function as called.
//     for &f in functions {
//         if f.entity.token == entity.token { f.called = true }
//     }

//     b := emit(f, token, Call_Function{
//         address = entity.address,
//         name = entity.name,
//     })

//     for output in ef.outputs {
//         if type_is_polymorphic(output) {
//             v, ok := parapoly_table[output.name]

//             if !ok {
//                 compilation_error(
//                     checker.curr_function,
//                     "parapoly of the name {} not defined in inputs",
//                     output.name,
//                 )
//             }

//             f.stack->push(v)
//         } else {
//             f.stack->push(output)
//         }
//     }
// }

// parse_function :: proc(e: ^Entity) {
//     ef := e.variant.(Entity_Function)
//     push_function(e)
//     f := checker.curr_function
//     stack_create(f)

//     for T in ef.inputs {
//         f.stack->push(T)
//     }

//     body_loop: for {
//         if f.errored {
//             for {
//                 if next().kind == .Semicolon {
//                     break body_loop
//                 }
//             }
//         }

//         if !parse_token(next(), f) {
//             break body_loop
//         }
//     }

//     if len(f.stack.v) != len(ef.outputs) {
//         parsing_error(
//             e.token,
//             "stack does not match function output.\n\tExpected: {}\n\tGot: {}",
//             len(ef.outputs), len(f.stack.v),
//         )
//     }

//     pop_function()
// }

// parse_token :: proc(token: Token, f: ^Function) -> bool {
//     switch token.kind {
//     case .EOF, .Invalid, .Fn, .Using, .Dash_Dash_Dash, .Foreign, .Builtin, .Type, .Proc:
//         parsing_error(
//             token.pos,
//             "invalid token in function body {}",
//             token_to_string(token),
//         )

//     case .Semicolon:
//         emit(f, token, Return{})
//         return false

//     case .Hat:

//     case .Ampersand:
//         t := expect(.Word)
//         parse_word(f, t)
//         A := f.stack->pop()
//         f.stack->push(type_create_pointer(A))

//     case .Const: declare_const()
//     case .Var:   declare_var()

//     case .Word: parse_word(f, token)
//     case .As:
//     case .Let:
//         scope := push_scope(token, .Let)
//         words := make([dynamic]Token, context.temp_allocator)
//         defer delete(words)

//         for !allow(.In) {
//             token := expect(.Word)
//             append(&words, token)
//         }

//         bind_words(f, words[:])
//         emit(f, token, Let_Bind{len(words)})

//     case .In: unimplemented()

//     case .Case: unimplemented()

//     case .If:
//         A := f.stack->pop()

//         if !types_equal(A, checker.basic_types[.Bool]) {
//             compilation_error(f, "Non-boolean condition in 'if' statement")
//         }

//         scope := push_scope(token, .If)
//         scope.validation_at_end = .Stack_Is_Unchanged
//         scope.start_op = emit(f, token, If{})
//         create_stack_snapshot(f, scope)
//         f.stack->save()

//     case .Else:
//         if checker.curr_scope.kind != .If {
//             compilation_error(f, "'else' unattached to an 'if' statement")
//         }

//         checker.curr_scope.kind = .If_Else
//         checker.curr_scope.validation_at_end = .Stack_Match_Between
//         refresh_stack_snapshot(f, checker.curr_scope)
//         f.stack->reset()
//         b := emit(f, token, Else{checker.curr_scope.start_op.address})
//         checker.curr_scope.start_op = b

//     case .Fi:
//         should_error := true
//         close_if_statements: for {
//             switch {
//             case checker.curr_scope.kind == .If:
//                 b := emit(f, token, Fi{checker.curr_scope.start_op.address})
//                 should_error = false
//                 pop_scope()
//                 f.stack->reset()
//                 break close_if_statements
//             case checker.curr_scope.kind == .If_Else:
//                 b := emit(f, token, Fi{checker.curr_scope.start_op.address})
//                 should_error = false
//                 create_stack_snapshot(f, checker.curr_scope)
//                 pop_scope()
//             case :
//                 if should_error {
//                     compilation_error(f, "'fi' unattached to an 'if' statement")
//                 }
//                 break close_if_statements
//             }
//         }

//     case .For: parse_for_op(f, token, .For)
//     case .For_Star: parse_for_op(f, token, .For_Star)
//     case .End:
//         scope := checker.curr_scope

//         if scope.kind != .Let {
//             parsing_error(token, "'end' unattached to 'let'")
//         }

//         binds_count := 0
//         for e in checker.curr_scope.entities {
//             if _, ok := e.variant.(Entity_Binding); ok {
//                 binds_count += 1
//             }
//         }
//         emit(f, token, Let_Unbind{binds_count})
//         pop_scope()
//     case .Loop:
//         scope := checker.curr_scope

//         if scope.kind != .Loop {
//             parsing_error(token, "'loop' unattached to 'let'")
//         }

//         #partial switch v in scope.start_op.variant {
//             case For_String_Start: {
//                 emit(f, token, For_String_End{
//                     address = scope.start_op.address,
//                 })
//             }
//             case For_Infinite_Start: {
//                 A := f.stack->pop()

//                 stack_expect(
//                     token.pos,
//                     "Non-boolean condition in 'loop' statement",
//                     types_equal(A, checker.basic_types[.Bool]),
//                 )

//                 emit(f, token, For_Infinite_End{
//                     address = scope.start_op.address,
//                 })
//             }
//             case For_Range_Start: {
//                 b := emit(f, token, For_Range_End{
//                     address = scope.start_op.address,
//                     autoincrement = !scope.autoincrement ? .off : scope.autoincrement_value == 1 ? .down : .up,
//                 })
//             }
//             case: compiler_bug()
//         }
//         pop_scope()
//         f.stack->reset()

//     case .Leave: emit(f, token, Return{})

//     case .Brace_Left: unimplemented()
//     case .Brace_Right: unimplemented()
//     case .Bracket_Left: unimplemented()
//     case .Bracket_Right: unimplemented()
//     case .Paren_Left: unimplemented()
//     case .Paren_Right: unimplemented()
//     case .Binary_Literal: unimplemented()

//     case .Character_Literal:
//         emit(f, token, Push_Byte{token.text[0]})
//         f.stack->push(checker.basic_types[.Byte])
//     case .Bool_Literal:
//         emit(f, token, Push_Bool{token.text == "true"})
//         f.stack->push(checker.basic_types[.Bool])
//     case .Cstring_Literal:
//         emit(f, token, Push_Cstring{
//             push_string(token.text), len(token.text),
//         })
//         f.stack->push(checker.basic_types[.String])
//         f.stack->push(checker.basic_types[.Int])
//     case .Float_Literal: fmt.assertf(false, "unimplemented for now")
//     case .Hex_Literal: unimplemented()
//     case .Integer_Literal:
//         emit(f, token, Push_Int{strconv.atoi(token.text)})
//         f.stack->push(checker.basic_types[.Int])
//     case .Octal_Literal: unimplemented()
//     case .String_Literal:
//         emit(f, token, Push_String{push_string(token.text)})
//         f.stack->push(checker.basic_types[.String])
//     case .Uint_Literal:
//         emit(f, token, Push_Int{strconv.atoi(token.text)})
//         f.stack->push(checker.basic_types[.Int])

//     case .Drop:
//         f.stack->pop()
//         emit(f, token, Drop{})
//     case .Dup:
//         A := f.stack->pop()
//         emit(f, token, Dup{})
//         f.stack->push(A)
//         f.stack->push(A)
//     case .Dup_Star:
//         B := f.stack->pop()
//         A := f.stack->pop()
//         emit(f, token, Dup_Star{})
//         f.stack->push(A)
//         f.stack->push(A)
//         f.stack->push(B)
//     case .Nip:
//         B := f.stack->pop()
//         A := f.stack->pop()
//         emit(f, token, Nip{})
//         f.stack->push(B)
//     case .Over:
//         B := f.stack->pop()
//         A := f.stack->pop()
//         emit(f, token, Over{})
//         f.stack->push(A)
//         f.stack->push(B)
//         f.stack->push(A)
//     case .Rot:
//         C := f.stack->pop()
//         B := f.stack->pop()
//         A := f.stack->pop()
//         emit(f, token, Rot{})
//         f.stack->push(B)
//         f.stack->push(C)
//         f.stack->push(A)
//     case .Rot_Star:
//         C := f.stack->pop()
//         B := f.stack->pop()
//         A := f.stack->pop()
//         emit(f, token, Rot_Star{})
//         f.stack->push(C)
//         f.stack->push(A)
//         f.stack->push(B)
//     case .Swap:
//         B := f.stack->pop()
//         A := f.stack->pop()
//         emit(f, token, Swap{})
//         f.stack->push(B)
//         f.stack->push(A)
//     case .Take:
//         // Does nothing, this is just a word that takes the last value of the stack
//         // just make sure the stack is not empty.
//         if len(f.stack.v) == 0 { assert(false) }
//     case .Tuck:
//         B := f.stack->pop()
//         A := f.stack->pop()
//         emit(f, token, Tuck{})
//         f.stack->push(B)
//         f.stack->push(A)
//         f.stack->push(B)

//     case .Get_Byte: parse_memory_op(f, token, .get_byte)
//     case .Set:      parse_memory_op(f, token, .set)
//     case .Set_Star: parse_memory_op(f, token, .set_star)
//     case .Set_Byte: parse_memory_op(f, token, .set_byte)

//     case .Plus:          parse_binary_op(f, token, .add)
//     case .Minus:         parse_binary_op(f, token, .sub)
//     case .Star:          parse_binary_op(f, token, .mul)
//     case .Slash:         parse_binary_op(f, token, .div)
//     case .Percent:       parse_binary_op(f, token, .mod)

//     case .Equal:              parse_comparison_op(f, token, .eq)
//     case .Greater_Equal:      parse_comparison_op(f, token, .ge)
//     case .Greater_Equal_Auto: parse_comparison_op(f, token, .ge, true)
//     case .Greater_Than:       parse_comparison_op(f, token, .gt)
//     case .Greater_Than_Auto:  parse_comparison_op(f, token, .gt, true)
//     case .Less_Equal:         parse_comparison_op(f, token, .le)
//     case .Less_Equal_Auto:    parse_comparison_op(f, token, .le, true)
//     case .Less_Than:          parse_comparison_op(f, token, .lt)
//     case .Less_Than_Auto:     parse_comparison_op(f, token, .lt, true)
//     case .Not_Equal:          parse_comparison_op(f, token, .ne)
//     }

//     return true
// }

// bind_words :: proc(f: ^Function, t: []Token, mutable := false) {
//     check_scope := checker.curr_scope
//     new_binds_count := len(t)

//     for check_scope != nil {
//         for &e in check_scope.entities {
//             #partial switch &v in e.variant {
//                 case Entity_Binding: v.index += new_binds_count
//             }
//         }
//         check_scope = check_scope.parent
//     }

//     #reverse for word, index in t {
//         A := f.stack->pop()
//         append(&checker.curr_scope.entities, Entity{
//             address = get_local_address(f),
//             pos = word.pos,
//             name = word.text,
//             variant = Entity_Binding{
//                 index = index,
//                 type = A,
//                 internal = strings.starts_with(word.text, "__stanczyk__internal__"),
//                 mutable = mutable,
//             },
//         })
//     }
// }

// parse_word :: proc(f: ^Function, t: Token) {
//     result := find_entity(f, t)

//     switch v in result.variant {
//     case Entity_Binding:
//         emit(f, t, Push_Bound{val = v.index, mutable = v.mutable})
//         f.stack->push(v.type)
//     case Entity_Constant:
//         emit(f, t, v.value)
//         f.stack->push(v.type)
//     case Entity_Function:
//         switch {
//         case result.is_builtin: call_builtin_func(f, t, result)
//         case result.is_foreign: call_foreign_func(f, t, result)
//         case: call_function(result)
//         }
//     case Entity_Type:
//         unimplemented()
//     case Entity_Variable:
//         if result.is_global {
//             emit(f, t, Push_Var_Global{v.offset, false})
//         } else {
//             emit(f, t, Push_Var_Local{v.offset, false})
//         }
//         f.stack->push(v.type)
//     }
// }

// parse_binary_op :: proc(f: ^Function, t: Token, op: enum {
//     add, sub, mul, div, mod,
// }) {
//     B := f.stack->pop()
//     A := f.stack->pop()

//     // TODO: Add validations!
//     switch op {
//     case .add:
//         emit(f, t, Add{})
//         f.stack->push(A)
//     case .sub:
//         emit(f, t, Substract{})
//         f.stack->push(checker.basic_types[.Int])
//     case .mul:
//         emit(f, t, Multiply{})
//         f.stack->push(checker.basic_types[.Int])
//     case .div:
//         emit(f, t, Divide{})
//         f.stack->push(checker.basic_types[.Int])
//     case .mod:
//         emit(f, t, Modulo{})
//         f.stack->push(checker.basic_types[.Int])
//     }
// }

// parse_comparison_op :: proc(f: ^Function, t: Token, op: Comparison_Kind, autoincrement := false) {
//     B := f.stack->pop()
//     A := f.stack->pop()
//     emit(f, t, Comparison{op, autoincrement, A})
//     f.stack->push(checker.basic_types[.Bool])
// }

// parse_memory_op :: proc(f: ^Function, t: Token, op: enum { get_byte, set, set_byte, set_star }) {
//     switch op {
//     case .get_byte:
//         B := f.stack->pop()
//         A := f.stack->pop()
//         emit(f, t, Get_Byte{})
//         f.stack->push(checker.basic_types[.Byte])
//     case .set:
//         B := f.stack->pop()
//         A := f.stack->pop()

//         last_op := &f.code[len(f.code) - 1]

//         #partial switch &v in last_op.variant {
//             case Push_Bound: {
//                 if !v.mutable {
//                     parsing_error(
//                         t, "can't rebind value of binding in 'let' scope. Maybe you wanted to use 'let*'?",
//                     )
//                 }
//                 v.use_pointer = true
//             }
//             case Push_Var_Global: v.use_pointer = true
//             case Push_Var_Local: v.use_pointer = true
//             case: parsing_error(t, "no variable found while trying to do 'set'")
//         }

//         // Add validation for pointers
//         emit(f, t, Set{})
//     case .set_star:
//         B := f.stack->pop()
//         found := false
//         index := len(f.code) - 1
//         max_lookup_index := max(0, index - 10)

//         for !found && index > max_lookup_index {
//             test_op := &f.code[index]

//             #partial switch &v in test_op.variant {
//                 case Push_Bound: {
//                     if !v.mutable {
//                         parsing_error(
//                             t, "can't rebind value of binding in 'let' scope. Maybe you wanted to use 'let*'?",
//                         )
//                     }
//                     emit(f, t, Push_Bound{val = v.val, use_pointer = true})
//                     found = true
//                     break
//                 }
//                 case Push_Var_Global: {
//                     emit(f, t, Push_Var_Global{val = v.val, use_pointer = true})
//                     found = true
//                     break
//                 }
//                 case Push_Var_Local: {
//                     emit(f, t, Push_Var_Local{val = v.val, use_pointer = true})
//                     found = true
//                     break
//                 }
//             }

//             index -= 1
//         }

//         if !found {
//             parsing_error(t, "no variable found while trying to do 'set*'")
//         }

//         emit(f, t, Set{})
//     case .set_byte:
//         C := f.stack->pop()
//         B := f.stack->pop()
//         A := f.stack->pop()
//         emit(f, t, Set_Byte{})
//     }
// }

// parse_for_op :: proc(f: ^Function, t: Token, kind: enum { For, For_Star }) {
//     // We need to figure out here what type of loop the user wants to use.
//     // The conditions are the following:
//     //   - Stack has a boolean and last operation was a sequence comparison
//     //     (..> or ..<, including equals)
//     //   - Stack has a boolean and last operation is equal or not equal
//     //   - Stack has an array
//     //   - Stack has an string (which behaves similar to array)
//     scope := push_scope(t, .Loop)
//     scope.validation_at_end = .Stack_Is_Unchanged
//     words := make([dynamic]Token, context.temp_allocator)
//     defer delete(words)

//     // Check this stack type to figure out what to do...
//     T := f.stack->pop()

//     switch {
//     case type_is_basic(T, .Bool):
//         // This can be a regular range 'for' loop with autoincrement or a
//         // range loop with manual increment.
//         prev_op := pop(&f.code)
//         default_words := []string{"__stanczyk__internal__for_lhs__", "__stanczyk__internal__for_rhs__"}

//         #partial switch v in prev_op.variant {
//             case Comparison: {
//                 if kind == .For {
//                     internal_words: for {
//                         t2 := next()
//                         #partial switch t2.kind {
//                             case .Word: append(&words, t2)
//                             case .In: break internal_words
//                             case: parsing_error(t2, "unexpected token '{}' in 'for' loop", token_to_string(t2))
//                         }
//                     }
//                 }

//                 if len(words) < len(default_words) {
//                     default_words_to_add := default_words[len(words):]
//                     for w in default_words_to_add { t2 := t; t2.text = w; append(&words, t2) }
//                 }

//                 f.stack->push(v.operands)
//                 f.stack->push(v.operands)
//                 bind_words(f, words[:], true)

//                 scope.autoincrement = v.autoincrement
//                 scope.autoincrement_value = v.kind == .gt || v.kind == .ge ? -1 : 1
//                 scope.start_op = emit(f, t, For_Range_Start{v.kind})
//                 create_stack_snapshot(f, scope)
//                 f.stack->save()
//             }
//             case: {
//                 // No words expected to be bound here
//                 emit(f, t, prev_op.variant)
//                 scope.start_op = emit(f, t, For_Infinite_Start{})
//                 create_stack_snapshot(f, scope)
//                 f.stack->save()
//             }
//         }
//     case type_is_basic(T, .String):
//         default_words := []string{"__stanczyk__internal__for_char__", "__stanczyk__internal__for_inx__", "__stanczyk__internal__for_str__"}
//         append(&words, expect(.Word))
//         if allow(.Word) { append(&words, checker.prev_token) }
//         expect(.In)

//         if len(words) < len(default_words) {
//             default_words_to_add := default_words[len(words):]
//             for w in default_words_to_add { t2 := t; t2.text = w; append(&words, t2) }
//         }

//         f.stack->push(checker.basic_types[.Byte]) // character
//         f.stack->push(checker.basic_types[.Int])  // index
//         f.stack->push(checker.basic_types[.String]) // the original string
//         bind_words(f, words[:])
//         scope.start_op = emit(f, t, For_String_Start{})
//         create_stack_snapshot(f, scope)
//         f.stack->save()
//     case : unimplemented()
//         //case type_is_array(): not implemented
//     }
// }
