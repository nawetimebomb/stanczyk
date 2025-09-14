package main

Type :: struct {
    size:    int,
    name:    string,
    variant: union {
        Type_Basic,
    },
}

Type_Basic :: struct {
    name: string,
    kind: Type_Basic_Kind,
}

Type_Id :: struct {}

Type_Basic_Kind :: enum {
    Bool,
    Char,
    Float,
    Int,
    String,
    Uint,
}

BASIC_TYPES := []Type{
    {name = "bool",   size = 1, variant = Type_Basic{kind=.Bool}},
    {name = "char",   size = 1, variant = Type_Basic{kind=.Char}},
    {name = "float",  size = 8, variant = Type_Basic{kind=.Float}},
    {name = "int",    size = 8, variant = Type_Basic{kind=.Int}},
    {name = "string", size = 8, variant = Type_Basic{kind=.String}},
    {name = "uint",   size = 8, variant = Type_Basic{kind=.Uint}},
}

types_are_equal :: proc(t1, t2: ^Type) -> bool {
    switch variant in t1.variant {
    case Type_Basic:
        t2v, ok := t2.variant.(Type_Basic)
        return ok && variant.kind == t2v.kind
    }

    return false
}

type_to_string :: proc(t: ^Type) -> string {
    assert(t != nil)
    switch variant in t.variant {
    case Type_Basic:
        switch variant.kind {
        case .Bool:   return "bool"
        case .Char:   return "char"
        case .Float:  return "float"
        case .Int:    return "int"
        case .String: return "string"
        case .Uint:   return "uint"
        }
    }

    return "unreachable"
}

type_to_foreign_name :: proc(t: ^Type) -> string {
    if t == nil do return "TODO"
    #partial switch variant in t.variant {
    case Type_Basic:
        #partial switch variant.kind {
        case .Int:    return "s64"
        case .String: return "string"
        }
    }

    return "TODO"
}
