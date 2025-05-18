package main

import "core:reflect"

Type_Primitive_Kind :: enum u8 {
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
    kind: Type_Primitive_Kind,
}

Type :: struct {
    cname:   string,
    size:    int,
    variant: Type_Variant,
}

type_to_string :: proc(t: Type) -> string {
    switch v in t.variant {
    case Type_Primitive:
        return reflect.enum_name_from_value(v.kind) or_break
    }

    assert(false)
    return "Invalid"
}

type_is_float :: proc(v: Type_Variant) -> bool {
    if t, ok := v.(Type_Primitive); ok {
        return t.kind == .float
    }

    return false
}

type_is_int :: proc(v: Type_Variant) -> bool {
    if t, ok := v.(Type_Primitive); ok {
        return t.kind == .int
    }

    return false
}

type_is_string :: proc(v: Type_Variant) -> bool {
    if t, ok := v.(Type_Primitive); ok {
        return t.kind == .string
    }

    return false
}


type_is_number :: proc(a: Type_Variant) -> bool {
    switch v in a {
    case Type_Primitive:
        return v.kind == .float || v.kind == .int
    }

    return false
}

type_get_number_types :: proc(a, b: Type_Variant) -> (ap, bp, rp: Type_Primitive_Kind) {
    if av, ok := a.(Type_Primitive); ok {
        ap = av.kind
    }

    if bv, ok := b.(Type_Primitive); ok {
        bp = bv.kind
    }

    if ap == .float || bp == .float {
        rp = .float
    } else {
        rp = .int
    }

    assert(ap != .invalid && bp != .invalid)
    return
}

type_sum_result_variant :: proc(a, b: Type_Variant) -> Type_Variant {
    if av, ok := a.(Type_Primitive); ok {
        if bv, ok := b.(Type_Primitive); ok {
            switch {
            case av.kind == .string || bv.kind == .string:
                return Type_Primitive{ kind = .string }
            case av.kind == .float || bv.kind == .float:
                return Type_Primitive{ kind = .float }
            case :
                return Type_Primitive{ kind = .int }
            }
        }
    }

    assert(false)
    return Type_Primitive{ kind = .invalid }
}
