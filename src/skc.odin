package main

import "core:c/libc"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"
import "core:time"

NAME            :: "Stańczyk"
NAME_ABBREV     :: "skc"
NAME_FULL       :: "The Stańczyk Compiler"
VERSION_MAJOR   :: "0"
VERSION_MINOR   :: "7"

ARGUMENT_PREFIX     :: "a"
REGISTER_PREFIX     :: "r"
MULTI_RESULT_PREFIX :: "p"

File_Info :: struct {
    short_name:  string,
    filename:    string,
    fullpath:    string,
    source:      string,
    line_starts: [dynamic]int,
}

Compiler :: struct {
    errors:            [dynamic]Compiler_Error,
    error_reported:    bool,

    current_scope:     ^Scope,
    global_scope:      ^Scope,
    proc_scope:        ^Scope,

    basic_types:       [Type_Basic_Kind]^Type,

    parser:            ^Parser,
    current_ip:        int,
    lines_parsed:      int,
}

compiler_dir:      string
working_dir:       string
output_filename:   string

source_files:      [dynamic]File_Info
program_bytecode:  [dynamic]^Op_Code

// Defaults
switch_debug := true

compiler: Compiler

main :: proc() {
    tracking_allocator: mem.Tracking_Allocator
    default_allocator := context.allocator
    mem.tracking_allocator_init(&tracking_allocator, default_allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)

    error1, error2: os2.Error
    compiler_dir, error1 = os2.get_executable_directory(context.allocator)
    working_dir, error2  = os2.get_working_directory(context.allocator)

    if error1 != nil {
        fatalf(
            .Compiler,
            "failed to get compiler directory with error {}",
            error1,
        )
    }

    if error2 != nil {
        fatalf(
            .Compiler,
            "failed to get current working directory with error {}",
            error2,
        )
    }

    if len(os.args) < 2 {
        fatalf(
            .Compiler,
            "please provide the entry point to your program",
        )
    }

    if !strings.ends_with(os.args[1], ".sk") {
        fatalf(
            .Compiler,
            "entry point needs to end with '.sk'",
        )
    }

    input_filename := os.args[1]
    if !os2.is_file(input_filename) {
        fatalf(
            .Compiler,
            "entry point is not a file",
        )
    }
    extension := filepath.ext(input_filename)
    output_filename = fmt.aprintf("{}", input_filename[:len(input_filename)-len(extension)])


    compiler.global_scope = create_scope()
    push_scope(compiler.global_scope)

    for &t in BASIC_TYPES {
        create_entity(t.name, nil, Entity_Type{&t})
        v := t.variant.(Type_Basic)
        compiler.basic_types[v.kind] = &t
    }

    register_builtin_print_entity()

    accumulator := time.tick_now()
    add_source_file(working_dir, os.args[1])
    for &file_info in source_files {
        load_entire_file(&file_info)
        parse_file(&file_info)
    }

    free_all(context.temp_allocator)

    check_program_bytecode()
    frontend_time := time.duration_seconds(time.tick_lap_time(&accumulator))

    gen_program()
    codegen_time := time.duration_seconds(time.tick_lap_time(&accumulator))

    libc.system(fmt.ctprintf("gcc {0}.c -o {0}", output_filename))
    compile_time := time.duration_seconds(time.tick_lap_time(&accumulator))
    alloc_amount := tracking_allocator.current_memory_allocated

    fmt.printf("\tLines processed.............{}\n",     compiler.lines_parsed)
    fmt.printf("\tCompiler Front-end..........%.6fs\n",  frontend_time)
    fmt.printf("\tCode generation.............%.6fs\n",  codegen_time)
    fmt.printf("\tCompiler Back-end...........%.6fs\n",  compile_time)
    fmt.printf("\tMemory used.................%.5fmb\n", (f64(alloc_amount)/1024.)/1024.)
}

add_source_file :: proc(directory, filename: string) {
    file_info := File_Info{
        filename  = strings.clone(filename),
        fullpath  = fmt.aprintf("{}/{}", directory, filename),
    }

    file_info.short_name = filepath.short_stem(file_info.filename)

    for other in source_files {
        if other.fullpath == file_info.fullpath {
            delete(file_info.fullpath)
            delete(file_info.filename)
            return
        }
    }

    append(&source_files, file_info)
}

load_entire_file :: proc(file_info: ^File_Info) {
    data, error := os2.read_entire_file_from_path(file_info.fullpath, context.temp_allocator)
    if error != nil {
        fatalf(
            .Compiler,
            "failed to load file '{}' with error {}",
            file_info.fullpath, error,
        )
    }

    file_info.source = strings.clone(string(data))
}

is_global_scope :: proc() -> bool {
    return compiler.current_scope == compiler.global_scope
}

has_error :: #force_inline proc() -> bool {
    return compiler.error_reported
}

make_token :: proc(text: string) -> Token {
    result: Token
    result.text = text
    return result
}
