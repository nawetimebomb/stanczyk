package main

Type :: struct {
    size_in_bytes: int,
    name:          string,
    foreign_name:  string,
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
    name: string,
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
        foreign_name  = "b8",
        size_in_bytes = 1,
        variant       = Type_Basic{kind=.Bool},
    },

    .Byte = {
        name          = "byte",
        foreign_name  = "u8",
        size_in_bytes = 1,
        variant       = Type_Basic{kind=.Byte},
    },

    .Float = {
        name          = "float",
        foreign_name  = "f64",
        size_in_bytes = 8,
        variant = Type_Basic{kind=.Float},
    },

    .Int = {
        name          = "int",
        foreign_name  = "s64",
        size_in_bytes = 8,
        variant       = Type_Basic{kind=.Int},
    },

    .String = {
        name          = "string",
        foreign_name  = "string",
        size_in_bytes = 8,
        variant       = Type_Basic{kind=.String},
    },

    .Uint = {
        name          = "uint",
        foreign_name  = "u64",
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
