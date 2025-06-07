package main

import "core:fmt"
import "core:reflect"

Type :: struct {
    size: uint,
    name: string,
    variant: Type_Variant,
}

Type_Variant :: union {
    Type_Any,
    Type_Array,
    Type_Basic,
    Type_Nil,
    Type_Polymorphic,
    Type_Pointer,
}

Type_Any :: struct {}

Type_Array :: struct {
    length: int,
    type: ^Type,
}

Type_Basic :: struct {
    kind: Type_Basic_Kind,
}

Type_Nil :: struct {}

Type_Pointer :: struct {
    type: ^Type,
}

Type_Polymorphic :: struct {}

Type_Basic_Kind :: enum u8 {
    Bool,
    Byte,
    Int,
    String,
}

type_create_pointer :: proc(t: ^Type) -> ^Type {
    return new_clone(Type{
        size = 8,
        variant = Type_Pointer{ type = t },
    }, context.temp_allocator)
}

types_equal :: proc(a, b: ^Type) -> bool {
    switch va in a.variant {
    case Type_Any:
        vb := b.variant.(Type_Any) or_return
    case Type_Array:
        vb := b.variant.(Type_Array) or_return
        if va.length != vb.length do return false
        if !types_equal(va.type, vb.type) do return false
    case Type_Basic:
        vb := b.variant.(Type_Basic) or_return
        if va.kind != vb.kind do return false
    case Type_Nil:
        vb := b.variant.(Type_Nil) or_return
    case Type_Pointer:
        vb := b.variant.(Type_Pointer) or_return
        if !types_equal(va.type, vb.type) do return false
    case Type_Polymorphic:
        vb := b.variant.(Type_Polymorphic) or_return
    }
    return true
}

type_is_any :: proc(t: ^Type) -> bool {
    v := t.variant.(Type_Any) or_return
    return true
}

type_is_basic :: proc(t: ^Type, k: Type_Basic_Kind) -> bool {
    v := t.variant.(Type_Basic) or_return
    if v.kind != k do return false
    return true
}

type_is_pointer :: proc(t: ^Type) -> bool {
    v := t.variant.(Type_Pointer) or_return
    return true
}

type_is_polymorphic :: proc(t: ^Type) -> bool {
    v := t.variant.(Type_Polymorphic) or_return
    return true
}

type_string_to_basic :: proc(s: string) -> Type_Basic_Kind {
    switch s {
    case "bool":   return .Bool
    case "byte":   return .Byte
    case "int":    return .Int
    case "string": return .String
    }
    assert(false)
    return .Bool
}

type_string_to_Type :: proc(s: string) -> ^Type {
    switch s {
    case "any":    return new_clone(Type{variant = Type_Any{}}, context.temp_allocator)
    case "bool":   return checker.basic_types[.Bool]
    case "byte":   return checker.basic_types[.Byte]
    case "int":    return checker.basic_types[.Int]
    case "string": return checker.basic_types[.String]
    case : return new_clone(Type{name = s, variant = Type_Polymorphic{}}, context.temp_allocator)
    }
    assert(false)
    return new_clone(Type{})
}

type_to_string :: proc(t: ^Type) -> string {
    switch v in t.variant {
    case Type_Any: return "any"
    case Type_Array: return fmt.tprintf("[]{}", type_to_string(v.type))
    case Type_Basic:
        switch v.kind {
        case .Bool: return "bool"
        case .Byte: return "byte"
        case .Int: return "int"
        case .String: return "string"
        }
    case Type_Nil: return "nil"
    case Type_Polymorphic: return "polymorphic"
    case Type_Pointer: return fmt.tprintf("{}*", type_to_string(v.type))
    }

    assert(false)
    return ""
}
