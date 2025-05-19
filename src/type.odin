package main

import "core:reflect"

type_test_proc :: #type proc(Type) -> bool

Primitive :: enum u8 {
    invalid = 0,
    bool,
    float,
    int,
    string,
}

Type_Variant :: union {
    Type_Primitive,
}

Type_Primitive :: struct {
    kind: Primitive,
}

Type :: struct {
    cname:   string,
    size:    int,
    variant: Type_Variant,
}

type_is_bool :: proc(t: Type) -> bool {
    switch v in t.variant {
    case Type_Primitive:
        return v.kind == .bool
    }

    return false
}

type_is_float :: proc(t: Type) -> bool {
    switch v in t.variant {
    case Type_Primitive:
        return v.kind == .float
    }

    return false
}

type_is_int :: proc(t: Type) -> bool {
    switch v in t.variant {
    case Type_Primitive:
        return v.kind == .int
    }

    return false
}

type_is_string :: proc(t: Type) -> bool {
    switch v in t.variant {
    case Type_Primitive:
        return v.kind == .string
    }

    return false
}

type_to_string :: proc(t: Type) -> string {
    switch v in t.variant {
    case Type_Primitive:
        return reflect.enum_name_from_value(v.kind) or_break
    }

    assert(false)
    return "Invalid"
}
