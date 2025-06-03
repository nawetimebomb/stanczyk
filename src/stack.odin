package main

import "core:fmt"
import "core:slice"
import "core:strings"

Value :: struct {
    address: uint,
    kind:    Type_Kind,
}

Stack :: struct {
    free:  proc(s: ^Stack),
    pop:   proc(s: ^Stack) -> (v: Value),
    push:  proc(s: ^Stack, v: Value),
    reset: proc(s: ^Stack),
    save:  proc(s: ^Stack),

    v: [dynamic]Value,
    snapshot: []Value,
}

stack_create :: proc(f: ^Function) {
    stack_free :: proc(s: ^Stack) {
        delete(s.v)
        delete(s.snapshot)
    }

    stack_pop :: proc(s: ^Stack) -> (v: Value) {
        assert(len(s.v) > 0)
        return pop(&s.v)
    }

    stack_push :: proc(s: ^Stack, v: Value) {
        append(&s.v, v)
    }

    stack_reset :: proc(s: ^Stack) {
        delete(s.v)
        s.v = slice.clone_to_dynamic(s.snapshot)
        delete(s.snapshot)
    }

    stack_save :: proc(s: ^Stack) {
        fmt.assertf(len(s.snapshot) > 0, "ERROR: There's an existing saved snapshot")
        s.snapshot = slice.clone(s.v[:])
    }

    f.stack = Stack{
        free = stack_free,
        pop = stack_pop,
        push = stack_push,
        reset = stack_reset,
        save = stack_save,

        v = make([dynamic]Value, 0, 2),
    }
}

stack_prettyprint :: proc(s: ^Stack) -> string {
    if len(s.v) == 0 {
        return "()"
    }
    // temp allocated since it might be used in errors
    builder := strings.builder_make(context.temp_allocator)
    fmt.sbprint(&builder, "(")

    for v, index in s.v {
        if len(s.v) - 1 == index {
            fmt.sbprintf(&builder, "{})", type_readable_table[v.kind])
        } else {
            fmt.sbprintf(&builder, "{} ", type_readable_table[v.kind])
        }
    }

    return strings.to_string(builder)

}

// OLD CODE STARTS HERE

Type_Stack_Value :: [dynamic]Type_Kind

Type_Stack :: struct {
    clear: proc(t: ^Type_Stack),
    peek: proc(t: ^Type_Stack) -> (k: Type_Kind),
    pop: proc(t: ^Type_Stack, loc := #caller_location) -> (k: Type_Kind),
    push: proc(t: ^Type_Stack, k: Type_Kind),
    reset: proc(t: ^Type_Stack),
    save: proc(t: ^Type_Stack),
    v: [dynamic]Type_Kind,
    saved: []Type_Kind,
}

init_type_stack :: proc(t: ^Type_Stack) {
    ts_clear :: proc(t: ^Type_Stack) {
        clear(&t.v)
    }

    ts_peek :: proc(t: ^Type_Stack) -> (k: Type_Kind) {
        return t.v[len(t.v) - 1]
    }

    ts_pop :: proc(t: ^Type_Stack, loc := #caller_location) -> (k: Type_Kind) {
        fmt.assertf(len(t.v) > 0, "stack is empty, missing data in {}", loc)
        return pop(&t.v)
    }

    ts_push :: proc(t: ^Type_Stack, k: Type_Kind) {
        append(&t.v, k)
    }

    ts_reset :: proc(t: ^Type_Stack) {
        delete(t.v)
        t.v = slice.clone_to_dynamic(t.saved)
    }

    ts_save :: proc(t: ^Type_Stack) {
        t.saved = slice.clone(t.v[:], context.temp_allocator)
    }

    t.clear = ts_clear
    t.peek = ts_peek
    t.pop = ts_pop
    t.push = ts_push
    t.reset = ts_reset
    t.save = ts_save
    t.v = make([dynamic]Type_Kind, context.temp_allocator)
}

pretty_print_stack :: proc(t: ^Type_Stack) -> string {
    if len(t.v) == 0 {
        return "()"
    }
    builder := strings.builder_make(context.temp_allocator)
    fmt.sbprint(&builder, "(")

    for v, index in t.v {
        if len(t.v) - 1 == index {
            fmt.sbprintf(&builder, "{})", type_readable_table[v])
        } else {
            fmt.sbprintf(&builder, "{} ", type_readable_table[v])
        }
    }

    return strings.to_string(builder)

}
