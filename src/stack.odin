package main

import "core:slice"

Reference :: struct {

}

Reference_Stack :: struct {
    clear: proc(t: ^Reference_Stack),
    pop: proc(t: ^Reference_Stack) -> (r: Reference),
    push: proc(t: ^Reference_Stack, r: Reference),
    v: [dynamic]Reference,
}

Type_Stack_Value :: [dynamic]Type_Kind

Type_Stack :: struct {
    clear: proc(t: ^Type_Stack),
    pop: proc(t: ^Type_Stack) -> (k: Type_Kind),
    push: proc(t: ^Type_Stack, k: Type_Kind),
    reset: proc(t: ^Type_Stack),
    save: proc(t: ^Type_Stack),
    v: [dynamic]Type_Kind,
    saved: []Type_Kind,
}

init_reference_stack :: proc(t: ^Reference_Stack) {
    rs_clear :: proc(t: ^Reference_Stack) {
        clear(&t.v)
    }

    rs_pop :: proc(t: ^Reference_Stack) -> (r: Reference) {
        assert(len(t.v) > 0)
        return pop(&t.v)
    }

    rs_push :: proc(t: ^Reference_Stack, r: Reference) {
        append(&t.v, r)
    }

    t.clear = rs_clear
    t.pop = rs_pop
    t.push = rs_push
    t.v = make([dynamic]Reference, context.temp_allocator)
}

init_type_stack :: proc(t: ^Type_Stack) {
    ts_clear :: proc(t: ^Type_Stack) {
        clear(&t.v)
    }

    ts_pop :: proc(t: ^Type_Stack) -> (k: Type_Kind) {
        assert(len(t.v) > 0)
        return pop(&t.v)
    }

    ts_push :: proc(t: ^Type_Stack, k: Type_Kind) {
        append(&t.v, k)
    }

    ts_reset :: proc(t: ^Type_Stack) {
        delete(t.v)
        t.v = slice.clone_to_dynamic(t.saved)
        delete(t.saved)
    }

    ts_save :: proc(t: ^Type_Stack) {
        t.saved = slice.clone(t.v[:])
    }

    t.clear = ts_clear
    t.pop = ts_pop
    t.push = ts_push
    t.reset = ts_reset
    t.save = ts_save
    t.v = make([dynamic]Type_Kind, context.temp_allocator)
}
