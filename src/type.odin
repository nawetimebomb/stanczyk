package main

Type :: struct {
    size:    uint,
    name:    string,
    variant: Type_Variant,
}

Type_Variant :: union {
    Type_Basic,
}

Type_Basic :: struct {
    kind: Type_Basic_Kind,
}

Type_Basic_Kind :: enum {
    Bool,
    Char,
    Float,
    Int,
    String,
    Uint,
}

types: [dynamic]^Type

init_types :: proc() {
    append(&types, new_clone(Type{size=1, name="bool",    variant=Type_Basic{.Bool}}))
    append(&types, new_clone(Type{size=1, name="char",    variant=Type_Basic{.Char}}))
    append(&types, new_clone(Type{size=8, name="float",   variant=Type_Basic{.Float}}))
    append(&types, new_clone(Type{size=8, name="int",     variant=Type_Basic{.Int}}))
    append(&types, new_clone(Type{size=8, name="string",  variant=Type_Basic{.String}}))
    append(&types, new_clone(Type{size=8, name="uint",    variant=Type_Basic{.Uint}}))
}

get_basic_type :: proc(kind: Type_Basic_Kind) -> ^Type {
    for type in types {
        #partial switch v in type.variant {
        case Type_Basic:
            if v.kind == kind {
                return type
            }
        }
    }

    return nil
}

get_type_by_name :: proc(name: string) -> ^Type {
    for type in types {
        if type.name == name {
            return type
        }
    }

    return nil
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
