package main

import "core:fmt"
import "core:reflect"

type_test_proc :: #type proc(Type) -> bool

Type :: struct {
    align: int,
    size:  int,
    variant: union {
        Type_Boolean,
        Type_Float,
        Type_Integer,
        Type_Named,
        Type_Pointer,
        Type_String,
    },
}

Type_Boolean :: struct {}

Type_Float :: struct {}

Type_Integer :: struct {
    is_signed: bool,
}

Type_Named :: struct {} // TODO

Type_Pointer :: struct {} // TODO

Type_String :: struct {
    is_cstring: bool,
}

TYPE_BOOLEAN :: proc() -> Type {
    return Type{variant = Type_Boolean{}}
}

TYPE_FLOAT :: proc(size := word_size_in_bits) -> Type {
    return Type{size = size, variant = Type_Float{}}
}

TYPE_INTEGER :: proc(is_signed := true, size := word_size_in_bits) -> Type {
    return Type{size = size, variant = Type_Integer{is_signed = is_signed}}
}

TYPE_POINTER :: proc(base: Type) -> Type {
    return Type{variant = Type_Pointer{}}
}

TYPE_STRING  :: proc(is_cstring := false) -> Type {
    return Type{variant = Type_String{is_cstring = is_cstring}}
}

type_is_boolean :: proc(t: Type) -> (ok: bool) {
    _, ok = t.variant.(Type_Boolean)
    return
}

type_is_float :: proc(t: Type) -> (ok: bool) {
    _, ok = t.variant.(Type_Float)
    return
}

type_is_integer :: proc(t: Type) -> (ok: bool) {
    _, ok = t.variant.(Type_Integer)
    return
}

type_is_string :: proc(t: Type) -> (ok: bool) {
    _, ok = t.variant.(Type_String)
    return
}

type_to_cname :: proc(t: Type) -> string {
    switch v in t.variant {
    case Type_Boolean: return "bool"
    case Type_Float: return fmt.tprintf("f{}", t.size)
    case Type_Integer: return fmt.tprintf("{}{}", v.is_signed ? "s" : "u", t.size)
    case Type_Named: assert(false); return "invalid"
    case Type_Pointer: assert(false); return "invalid"
    case Type_String: return v.is_cstring ? "cstring" : "string"
    }

    assert(false)
    return "invalid"
}
