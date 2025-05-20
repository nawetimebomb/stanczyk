package main

import "core:fmt"

sim_stack: [dynamic]Type

sim_expect :: proc(p: ^Procedure, m: ..bool) {
    for x in m {
        if !x {
            p.error = true
            break
        }
    }
}

sim_at_least :: proc(a: int) -> bool {
    return len(sim_stack) >= a
}

sim_at_least_same_type :: proc(a: int) -> bool {
    if sim_at_least(a) {
        t := sim_peek()

        for x := 1; x <= a; x += 1 {
            if t != sim_stack[len(sim_stack) - x] {
                return false
            }
        }

        return true
    }

    return false
}

sim_match_type :: proc(m: Type) -> bool {
    t := sim_peek()
    return m == t
}

sim_one_of_primitive :: proc(m: ..Primitive) -> bool {
    t := sim_peek()

    if type_is_primitive(t) {
        tp := type_get_primitive(t)
        for x in m { if tp == x { return true }}
    }

    return false
}

sim_match :: proc(a: int, m: []Type) -> bool {
    sim_at_least(a)
    stack_slice := sim_stack[len(sim_stack) - a:]
    for x, i in m { if stack_slice[i] != x { return false }}
    return true
}

sim_peek :: proc() -> Type {
    return sim_stack[len(sim_stack) - 1]
}

sim_pop :: proc() -> Type {
    return pop(&sim_stack)
}

sim_pop2 :: proc() -> (a, b: Type) {
    return pop(&sim_stack), pop(&sim_stack)
}

sim_push :: proc(t: Type) {
    append(&sim_stack, t)
}
