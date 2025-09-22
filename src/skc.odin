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
GIT_URL         :: "https://github.com/nawetimebomb/stanczyk"

File_Info :: struct {
    short_name:  string,
    filename:    string,
    fullpath:    string,
    source:      string,
    line_starts: [dynamic]int,
}

Compiler :: struct {
    errors:           [dynamic]Compiler_Error,
    error_reported:   bool,

    current_scope:    ^Scope,
    current_proc:     ^Procedure,
    global_proc:      ^Procedure,

    types:            map[string]^Type,

    foreign_name_uid: int,
    parser:           ^Parser,
    lines_parsed:     int,
    main_found_at:    ^Token,
}

compiler_dir:      string
working_dir:       string
output_filename:   string

source_files: [dynamic]File_Info
bytecode:     [dynamic]^Procedure

// Defaults
switch_debug  := false
switch_silent := false

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

    if len(os.args) > 2 {
        options := os.args[2:]

        for s in options {
            switch s {
            case "-silent": switch_silent = true
            case "-debug":  switch_debug  = true
            }
        }
    }

    global_proc := new(Procedure)
    global_proc.is_global = true
    global_proc.scope = create_scope(.Global)
    push_procedure(global_proc)
    compiler.global_proc = global_proc

    register_global_type(type_bool)
    register_global_type(type_byte)
    register_global_type(type_float)
    register_global_type(type_int)
    register_global_type(type_string)
    register_global_type(type_uint)

    register_global_const_entities()

    accumulator := time.tick_now()
    add_source_file(working_dir, os.args[1])
    for &file_info in source_files {
        load_entire_file(&file_info)
        parse_file(&file_info)
    }

    free_all(context.temp_allocator)

    check_program_bytecode()
    frontend_time := time.duration_seconds(time.tick_lap_time(&accumulator))

    free_all(context.temp_allocator)

    //gen_program()
    codegen_time := time.duration_seconds(time.tick_lap_time(&accumulator))

    debug_print_bytecode()

    libc.system(fmt.ctprintf("gcc {0}.c -o {0} -ggdb", output_filename))
    compile_time := time.duration_seconds(time.tick_lap_time(&accumulator))
    alloc_amount := tracking_allocator.current_memory_allocated

    if !switch_debug {
        _ = os2.remove(fmt.tprintf("{}.c", output_filename))
    }

    if !switch_silent {
        fmt.printf("\tLines processed.............{}\n",     compiler.lines_parsed)
        fmt.printf("\tCompiler Front-end..........%.6fs\n",  frontend_time)
        fmt.printf("\tCode generation.............%.6fs\n",  codegen_time)
        fmt.printf("\tCompiler Back-end...........%.6fs\n",  compile_time)
        fmt.printf("\tMemory used.................%.5fmb\n", (f64(alloc_amount)/1024.)/1024.)
    }
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

has_error :: #force_inline proc() -> bool {
    return compiler.error_reported
}

make_token :: proc(text: string) -> Token {
    result: Token
    result.text = text
    return result
}
