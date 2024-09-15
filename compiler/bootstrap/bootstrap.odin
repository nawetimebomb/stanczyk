package skc

import "core:fmt"
import "core:mem"

SK__StackValue :: union #no_nil { int, bool, f64, string, }

sk__stack: [dynamic]SK__StackValue

sk__push :: proc(v: SK__StackValue) {
    append(&sk__stack, v)
}

sk__pop :: proc() -> SK__StackValue {
    v := pop(&sk__stack)
    return v
}

sk__print :: proc() {
    fmt.print(sk__pop())
}

sk__sum :: proc() {
    b := sk__pop()
    a := sk__pop()
    sk__push(a.(int) + b.(int))
}

sk__substract :: proc() {
    b := sk__pop()
    a := sk__pop()
    sk__push(a.(int) - b.(int))
}

sk__multiply :: proc() {
    b := sk__pop()
    a := sk__pop()
    sk__push(a.(int) * b.(int))
}

sk__divide :: proc() {
    b := sk__pop()
    a := sk__pop()
    sk__push(a.(int) / b.(int))
}

sk__modulo :: proc() {
    b := sk__pop()
    a := sk__pop()
    sk__push(a.(int) % b.(int))
}

main :: proc() {
    arena: mem.Arena
    data: [256]byte
    mem.arena_init(&arena, data[:])
    allocator := mem.arena_allocator(&arena)
    sk__stack = make([dynamic]SK__StackValue, 0, 255, allocator)
    sk__fn_main()
}
