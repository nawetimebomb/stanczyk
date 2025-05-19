package main

import "core:reflect"

type_test_proc :: #type proc(Type) -> bool

Type :: struct {
    cname:   string,
    size:    int,
    variant: Type_Variant,
}

Type_Variant :: union {
    Type_Primitive,
    Type_Pointer,
}

Primitive :: enum u8 {
    invalid = 0,
    bool,
    float,
    int,
    string,
}

Type_Primitive :: struct {
    kind: Primitive,
}

Type_Pointer :: struct {
    kind: Primitive,
}

type_create_pointer :: proc(t: Primitive) -> Type {
    return Type{ variant = Type_Pointer{ kind = t }}
}

type_create_primitive :: proc(t: Primitive) -> Type {
    return Type{ variant = Type_Primitive{ kind = t }}
}

type_get_primitive :: proc(t: Type) -> Primitive {
    if v, ok := t.variant.(Type_Primitive); ok {
        return v.kind
    }

    assert(false)
    return .invalid
}

type_is_bool :: proc(t: Type) -> bool {
    #partial switch v in t.variant {
        case Type_Primitive: return v.kind == .bool
    }

    return false
}

type_is_float :: proc(t: Type) -> bool {
    #partial switch v in t.variant {
        case Type_Primitive: return v.kind == .float
    }

    return false
}

type_is_int :: proc(t: Type) -> bool {
    #partial switch v in t.variant {
        case Type_Primitive: return v.kind == .int
    }

    return false
}

type_is_string :: proc(t: Type) -> bool {
    #partial switch v in t.variant {
        case Type_Primitive: return v.kind == .string
    }

    return false
}

type_is_primitive :: proc(t: Type) -> bool {
    #partial switch v in t.variant {
        case Type_Primitive: return true
    }

    return false
}

type_to_string :: proc(t: Type) -> string {
    switch v in t.variant {
    case Type_Primitive:
        return reflect.enum_name_from_value(v.kind) or_break
    case Type_Pointer:
        return "ptr"
    }

    assert(false)
    return "Invalid"
}
