package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

Value :: struct {
    address: uint,
    kind:    Type_Kind,
}

Stack :: struct {
    free:  proc(s: ^Stack),
    peek:  proc(s: ^Stack) -> (v: Value),
    pop:   proc(s: ^Stack) -> (v: Value),
    push:  proc(s: ^Stack, v: Value),
    reset: proc(s: ^Stack),
    save:  proc(s: ^Stack, loc := #caller_location),

    v: [dynamic]Value,
    snapshot: []Value,
}

stack_create :: proc(f: ^Function) {
    stack_free :: proc(s: ^Stack) {
        delete(s.v)
    }

    stack_peek :: proc(s: ^Stack) -> (v: Value) {
        return s.v[len(s.v) - 1]
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
    }

    stack_save :: proc(s: ^Stack, loc := #caller_location) {
        // fmt.assertf(len(s.snapshot) > 0, "ERROR: There's an existing saved snapshot {}", loc)
        s.snapshot = slice.clone(s.v[:], context.temp_allocator)
    }

    f.stack = Stack{
        free  = stack_free,
        peek  = stack_peek,
        pop   = stack_pop,
        push  = stack_push,
        reset = stack_reset,
        save  = stack_save,

        v = make([dynamic]Value, 0, 2),
    }
}

stack_expect :: proc(pos: Position, message: string, tests: ..bool) {
    for b in tests {
        if !b {
            fmt.eprint("stack validation error: ")
            fmt.eprintf("%s(%d:%d): ", pos.filename, pos.line, pos.column)
            fmt.eprintln(message)
            os.exit(1)
        }
    }
}

stack_match_arity :: proc(s: []Value, a: Arity) -> bool {
    if len(s) != len(a) { return false }
    for sx, index in s {
        ax := a[index]
        if sx.kind != ax.kind { return false }
    }
    return true
}

stack_prettyprint :: proc(message: string, values: ..Value) -> string {
    ppbuilder := strings.builder_make(context.temp_allocator)

    for v, index in values {
        if index == 0 {
            strings.write_string(&ppbuilder, "(")
            strings.write_string(&ppbuilder, type_readable_table[v.kind])
        } else if index == len(values) - 1 {
            strings.write_string(&ppbuilder, " ")
            strings.write_string(&ppbuilder, type_readable_table[v.kind])
            strings.write_string(&ppbuilder, ")")
        } else {
            strings.write_string(&ppbuilder, " ")
            strings.write_string(&ppbuilder, type_readable_table[v.kind])
        }
    }

    return fmt.tprintf(message, strings.to_string(ppbuilder))
}
