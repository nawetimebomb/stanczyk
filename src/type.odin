package main

import "core:reflect"

TYPE_ALL_FLOAT       :: []Primitive{.f64, .f32}
TYPE_ALL_INT         :: []Primitive{.s64, .s32, .s16, .s8}
TYPE_ALL_UINT        :: []Primitive{.u64, .u32, .u16, .u8}
TYPE_ALL_REAL_NUMBER :: []Primitive{.s64, .s32, .s16, .s8, .u64, .u32, .u16, .u8}
TYPE_ALL_NUMBER      :: []Primitive{.f64, .f32, .s64, .s32, .s16, .s8, .u64, .u32, .u16, .u8}
TYPE_ALL_PRIMITIVE   :: []Primitive{.bool, .f64, .f32, .s64, .s32, .s16, .s8, .string, .u64, .u32, .u16, .u8}

type_test_proc :: #type proc(Type) -> bool

// Type :: struct {
//     align: int,
//     size:  int,
//     variant: union {
//         Type_Named,
//         Type_Boolean,
//         Type_Float,
//         Type_Integer,
//         Type_Pointer,
//         Type_String,
//     }
// }

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
    f64,
    f32,
    s64,
    s32,
    s16,
    s8,
    string,
    u64,
    u32,
    u16,
    u8,
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
    switch v in t.variant {
    case Type_Primitive: return v.kind == .f64 || v.kind == .f32
    case Type_Pointer: return false
    }

    return false
}

type_is_int :: proc(t: Type) -> bool {
    switch v in t.variant {
    case Type_Primitive:
        return v.kind == .s64 || v.kind == .s32 ||
            v.kind == .s16 || v.kind == .s8
    case Type_Pointer:
        return false
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

type_to_cname :: proc(t: Type) -> string {
    switch v in t.variant {
    case Type_Primitive:
        switch v.kind {
        case .invalid: assert(false)
        case .bool:    return "bool"
        case .f64:     return "f64"
        case .f32:     return "f32"
        case .s64:     return "s64"
        case .s32:     return "s32"
        case .s16:     return "s16"
        case .s8:      return "s8"
        case .string:  return "string"
        case .u64:     return "u64"
        case .u32:     return "u32"
        case .u16:     return "u16"
        case .u8:      return "u8"
        }
    case Type_Pointer:
        return "ptr"
    }

    assert(false)
    return "Invalid"
}
