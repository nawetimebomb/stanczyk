package main

Type :: struct {
    size:    uint,
    name:    string,
    token:   Token,
    variant: Type_Variant,
}

Type_Variant :: union {
    Type_Basic,
    Type_Id,
}

Type_Basic :: struct {
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

types: [dynamic]^Type

init_types :: proc() {
    append(&types, new_clone(Type{size=1, name="bool",    variant=Type_Basic{.Bool}}))
    append(&types, new_clone(Type{size=1, name="char",    variant=Type_Basic{.Char}}))
    append(&types, new_clone(Type{size=8, name="float",   variant=Type_Basic{.Float}}))
    append(&types, new_clone(Type{size=8, name="int",     variant=Type_Basic{.Int}}))
    append(&types, new_clone(Type{size=8, name="string",  variant=Type_Basic{.String}}))
    append(&types, new_clone(Type{size=8, name="uint",    variant=Type_Basic{.Uint}}))
    append(&types, new_clone(Type{size=8, name="typeid",  variant=Type_Id{}}))
}

get_type_basic :: proc(kind: Type_Basic_Kind) -> ^Type {
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

types_are_equal :: proc(t1, t2: ^Type) -> bool {
    switch variant in t1.variant {
    case Type_Basic:
        t2v, ok := t2.variant.(Type_Basic)
        return ok && variant.kind == t2v.kind
    case Type_Id:
        _, ok := t2.variant.(Type_Id)
        return ok
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
    case Type_Id:     return "typeid"
    }

    return "unreachable"
}

type_to_cname :: proc(t: ^Type) -> string {
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
