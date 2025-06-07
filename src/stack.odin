package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

Stack :: struct {
    free:  proc(s: ^Stack),
    peek:  proc(s: ^Stack) -> (v: ^Type),
    pop:   proc(s: ^Stack, loc := #caller_location) -> (v: ^Type),
    push:  proc(s: ^Stack, v: ^Type),
    reset: proc(s: ^Stack),
    save:  proc(s: ^Stack, loc := #caller_location),

    v: [dynamic]^Type,
    snapshot: []^Type,
}

stack_create :: proc(f: ^Function) {
    stack_free :: proc(s: ^Stack) {
        delete(s.v)
    }

    stack_peek :: proc(s: ^Stack) -> (v: ^Type) {
        return s.v[len(s.v) - 1]
    }

    stack_pop :: proc(s: ^Stack, loc := #caller_location) -> (v: ^Type) {
        fmt.assertf(len(s.v) > 0, "called from {}", loc)
        return pop(&s.v)
    }

    stack_push :: proc(s: ^Stack, v: ^Type) {
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

        v = make([dynamic]^Type, 0, 2),
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

// stack_match_arity :: proc(s: []^Type, a: Arity) -> bool {
//     if len(s) != len(a) { return false }
//     for sx, index in s {
//         ax := a[index]
//         if sx != ax.kind { return false }
//     }
//     return true
// }

stack_prettyprint :: proc(message: string, values: ..^Type) -> string {
    ppbuilder := strings.builder_make(context.temp_allocator)

    for v, index in values {
        if len(values) == 1 {
            strings.write_string(&ppbuilder, "(")
            strings.write_string(&ppbuilder, type_to_string(v))
            strings.write_string(&ppbuilder, ")")
        } else if index == 0 {
            strings.write_string(&ppbuilder, "(")
            strings.write_string(&ppbuilder, type_to_string(v))
        } else if index == len(values) - 1 {
            strings.write_string(&ppbuilder, " ")
            strings.write_string(&ppbuilder, type_to_string(v))
            strings.write_string(&ppbuilder, ")")
        } else {
            strings.write_string(&ppbuilder, " ")
            strings.write_string(&ppbuilder, type_to_string(v))
        }
    }

    return fmt.tprintf(message, strings.to_string(ppbuilder))
}
