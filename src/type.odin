package main

import "core:fmt"
import "core:slice"
import "core:strings"

Type :: struct {
    size_in_bytes: int,
    name:          string,
    variant: union {
        Type_Alias,
        Type_Array,
        Type_Basic,
        Type_Pointer,
        Type_Proc,
        Type_Struct,
    },
}

Type_Alias :: struct {
    derived: ^Type,
    token:   Token,
}

Type_Array :: struct {
    length: int,
    type:   ^Type,
}

Type_Basic :: struct {
    kind: Type_Basic_Kind,
}

Type_Pointer :: struct {
    type: ^Type,
}

Type_Proc :: struct {
    arguments: []^Type,
    results:   []^Type,
}

Type_Struct :: struct {
    fields: []Type_Struct_Field,
}

Type_Struct_Field :: struct {
    offset:     int,
    name:       string,
    type:       ^Type,
    name_token: Token,
    type_token: Token,
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
        size_in_bytes = BYTE_SIZE,
        variant       = Type_Basic{kind=.Bool},
    },

    .Byte = {
        name          = "byte",
        size_in_bytes = BYTE_SIZE,
        variant       = Type_Basic{kind=.Byte},
    },

    .Float = {
        name          = "float",
        size_in_bytes = QWORD_SIZE,
        variant       = Type_Basic{kind=.Float},
    },

    .Int = {
        name          = "int",
        size_in_bytes = QWORD_SIZE,
        variant       = Type_Basic{kind=.Int},
    },

    .String = {
        name          = "string",
        size_in_bytes = QWORD_SIZE, // pointer
        variant       = Type_Basic{kind=.String},
    },

    .Uint = {
        name          = "uint",
        size_in_bytes = QWORD_SIZE,
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
    compiler.types_by_name[type.name] = type
    append(&compiler.types_array, type)
    create_entity(make_token(type.name), type)
}

type_pointer_to :: proc(type: ^Type) -> ^Type {
    for t in compiler.types_array {
        #partial switch v in t.variant {
        case Type_Pointer:
            if v.type == type {
                return t
            }
        }
    }

    t := new(Type)
    t.size_in_bytes = QWORD_SIZE
    t.name = fmt.aprintf("'{}", type.name)
    t.variant = Type_Pointer{type}

    return t
}

type_proc_create :: proc(arguments: []Parameter, results: []Parameter) -> ^Type {
    _create_type_proc_name :: proc(args, ress: []^Type) -> string {
        name := strings.builder_make()
        fmt.sbprint(&name, "proc(")
        for arg, index in args {
            fmt.sbprintf(
                &name, "{}{}", arg.name, index < len(args)-1 ? " " : "",
            )
        }

        if len(ress) > 0 {
            if len(args) > 0 {
                fmt.sbprint(&name, " ")
            }

            fmt.sbprint(&name, "--- ")

            for arg, index in ress {
                fmt.sbprintf(
                    &name, "{}{}", arg.name, index < len(args)-1 ? " " : "",
                )
            }
        }

        fmt.sbprint(&name, ")")
        return strings.to_string(name)
    }

    args_t := make([dynamic]^Type, context.temp_allocator)
    ress_t := make([dynamic]^Type, context.temp_allocator)

    for arg in arguments {
        append(&args_t, arg.type)
    }

    for res in results {
        append(&ress_t, res.type)
    }

    for t in compiler.types_array {
        if v, ok := t.variant.(Type_Proc); ok {
            if slice.equal(v.arguments, args_t[:]) && slice.equal(v.results, ress_t[:]) {
                return t
            }
        }
    }

    t := new(Type)
    t.size_in_bytes = QWORD_SIZE // a pointer
    t.name = _create_type_proc_name(args_t[:], ress_t[:])
    t.variant = Type_Proc{
        arguments = slice.clone(args_t[:]),
        results   = slice.clone(ress_t[:]),
    }

    append(&compiler.types_array, t)

    return t
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

type_is_pointer_of :: proc(type: ^Type, of: ^Type) -> bool {
    if variant, ok := type.variant.(Type_Pointer); ok {
        test_type := type_get_derived_type(variant.type)

        if test_type == of {
            return true
        }
    }

    return false
}

type_get_derived_type :: proc(type: ^Type) -> ^Type {
    if variant, ok := type.variant.(Type_Alias); ok {
        return type_get_derived_type(variant.derived)
    }
    return type
}

types_equal :: proc(test_a, test_b: ^Type) -> bool {
    a := type_get_derived_type(test_a)
    b := type_get_derived_type(test_b)

    switch va in a.variant {
    case Type_Alias:
        unreachable()

    case Type_Array:
        unimplemented()

    case Type_Basic:
        vb := b.variant.(Type_Basic) or_return
        if va.kind != vb.kind {
            return false
        }

    case Type_Pointer:
        vb := b.variant.(Type_Pointer) or_return
        if !types_equal(va.type, vb.type) {
            return false
        }
    case Type_Proc:
        vb := b.variant.(Type_Proc) or_return
        if !slice.equal(va.arguments[:], vb.arguments[:]) ||
            !slice.equal(va.results[:], vb.results[:]) {
            return false
        }

    case Type_Struct:
        unimplemented()

    }

    return true
}
