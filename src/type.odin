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
