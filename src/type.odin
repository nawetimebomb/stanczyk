package main

Type :: struct {
    size_in_bytes: int,
    name:          string,
    variant: union {
        Type_Alias,
        Type_Basic,
        Type_Procedure,
        Type_Struct,
    },
}

Type_Alias :: struct {
    derived: ^Type,
}

Type_Basic :: struct {
    kind: Type_Basic_Kind,
}

Type_Procedure :: struct {
    arguments: []^Type,
    results:   []^Type,
}

Type_Struct :: struct {
    names:        []string,
    types:        []^Type,
    fields_count: int,
}

Type_Basic_Kind :: enum {
    Bool,
    Byte,
    Float,
    Int,
    String,
    Uint,
}

BASIC_TYPES := [Type_Basic_Kind]Type{
    .Bool = {
        name          = "bool",
        size_in_bytes = 8, // alignment
        variant       = Type_Basic{kind=.Bool},
    },

    .Byte = {
        name          = "byte",
        size_in_bytes = 8,
        variant       = Type_Basic{kind=.Byte},
    },

    .Float = {
        name          = "float",
        size_in_bytes = 8,
        variant       = Type_Basic{kind=.Float},
    },

    .Int = {
        name          = "int",
        size_in_bytes = 8,
        variant       = Type_Basic{kind=.Int},
    },

    .String = {
        name          = "string",
        size_in_bytes = 8,
        variant       = Type_Basic{kind=.String},
    },

    .Uint = {
        name          = "uint",
        size_in_bytes = 8,
        variant       = Type_Basic{kind=.Uint},
    },
}

type_bool   := &BASIC_TYPES[.Bool]
type_byte   := &BASIC_TYPES[.Byte]
type_float  := &BASIC_TYPES[.Float]
type_int    := &BASIC_TYPES[.Int]
type_string := &BASIC_TYPES[.String]
type_uint   := &BASIC_TYPES[.Uint]

register_global_type :: proc(type: ^Type) {
    compiler.types[type.name] = type
    create_entity(make_token(type.name), Entity_Type{type})
}

type_one_of :: proc(type: ^Type, test_procs: ..proc(^Type) -> bool) -> bool {
    for cb in test_procs {
        if cb(type) {
            return true
        }
    }

    return false
}

type_is_boolean :: proc(type: ^Type) -> bool {
    if type == type_bool {
        return true
    }

    #partial switch variant in type.variant {
    case Type_Alias:
        return type_is_boolean(variant.derived)
    case Type_Basic:
        #partial switch variant.kind {
        case .Bool:
            return true
        }
    }

    return false
}


type_is_string :: proc(type: ^Type) -> bool {
    if type == type_string {
        return true
    }

    #partial switch variant in type.variant {
    case Type_Alias:
        return type_is_string(variant.derived)
    case Type_Basic:
        return variant.kind == .String
    }

    return false
}

type_is_integer :: proc(type: ^Type) -> bool {
    #partial switch variant in type.variant {
    case Type_Alias:
        return type_is_integer(variant.derived)
    case Type_Basic:
        #partial switch variant.kind {
        case .Int:
            return true
        }
    }

    return false
}

type_is_number :: proc(type: ^Type) -> bool {
    #partial switch variant in type.variant {
    case Type_Alias:
        return type_is_number(variant.derived)
    case Type_Basic:
        #partial switch variant.kind {
        case .Float, .Int, .Uint:
            return true
        }
    }

    return false
}

type_is_byte :: proc(type: ^Type) -> bool {
    if type == type_byte {
        return true
    }

    #partial switch variant in type.variant {
    case Type_Alias:
        return type_is_byte(variant.derived)
    case Type_Basic:
        return variant.kind == .Byte
    }

    return false
}
