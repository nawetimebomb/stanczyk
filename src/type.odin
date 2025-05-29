package main

import "core:fmt"
import "core:reflect"

Type :: struct {
    kind: Type_Kind,
    name: string,
}

Type_Kind :: enum u8 {
    Invalid = 0,
    Any,
    Bool,
    Byte,
    Float,
    Int,
    Parapoly,
    String,
    Uint,
    Variadic,
}

type_readable_table := [Type_Kind]string{
        .Invalid = "invalid",
        .Any = "any",
        .Bool = "bool",
        .Byte = "byte",
        .Float = "float",
        .Int = "int",
        .Parapoly = "parapoly",
        .String = "string",
        .Uint = "uint",
        .Variadic = "variadic",
}

type_string_to_kind :: proc(s: string) -> Type_Kind {
    switch s {
    case "any": return .Any
    case "bool": return .Bool
    case "byte": return .Byte
    case "float": return .Float
    case "int": return .Int
    case "string": return .String
    case "uint": return .Uint
    }

    assert(false)
    return .Invalid
}

type_to_cname :: proc(t: Type_Kind) -> string {
    switch t {
    case .Invalid: assert(false)
    case .Any: return "skany"
    case .Bool: return "skbool"
    case .Byte: return "skbyte"
    case .Float: return "skfloat"
    case .Int: return "skint"
    case .Parapoly: assert(false)
    case .String: return "skstring"
    case .Uint: return "skuint"
    case .Variadic: assert(false)
    }

    return "invalid"
}
