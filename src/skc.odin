package main

import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:strings"

NAME          :: "Stańczyk"
NAME_ABBREV   :: "skc"
NAME_FULL     :: "The Stańczyk Compiler"
VERSION_MAJOR :: "0"
VERSION_MINOR :: "7"
VERSION_PATCH :: "0"

Error :: enum u8 {
    None                           = 0,
    Compiler_Directory_Unreachable = 1,
    User_Directory_Unreachable     = 2,
    Compiler_Malformed_Arguments   = 3,
    Compiler_Failed_To_Load_File   = 4,
}

File_Info :: struct {
    directory: enum { User, Compiler },
    filename:  string,
    fullpath:  string,
    source:    string,
}

compiler_dir:      string
working_dir:       string
output_filename:   string
source_files:      [dynamic]File_Info
//compilation_units: [dynamic]^Ast
//to_validate_units: [dynamic]^Ast

// Defaults
switch_debug := true

main :: proc() {
    error1, error2: os2.Error
    compiler_dir, error1 = os2.get_executable_directory(context.allocator)
    working_dir, error2 = os2.get_working_directory(context.allocator)

    if error1 != nil {
        fatalf(
            .Compiler_Directory_Unreachable,
            "failed to get compiler directory with error {}",
            error1,
        )
    }

    if error2 != nil {
        fatalf(
            .User_Directory_Unreachable,
            "failed to get current working directory with error {}",
            error2,
        )
    }

    if len(os.args) < 2 {
        fatalf(
            .Compiler_Malformed_Arguments,
            "please provide the entry point to your program",
        )
    }

    if !strings.ends_with(os.args[1], ".sk") {
        fatalf(
            .Compiler_Malformed_Arguments,
            "entry point needs to end with '.sk'",
        )
    }


    append(&source_files, File_Info{
        directory = .User,
        filename  = os.args[1],
    })

    for len(source_files) > 0 {
        file_info := pop(&source_files)

        if len(file_info.source) == 0 {
            switch file_info.directory {
            case .User:
                file_info.fullpath = fmt.aprintf("{}/{}", working_dir, file_info.filename)
            case .Compiler:
                file_info.fullpath = fmt.aprintf("{}/{}", compiler_dir, file_info.filename)
            }

            load_entire_file(&file_info)
        }

        parse_file(&file_info)
    }
    // TODO(nawe) print results
}

load_entire_file :: proc(file_info: ^File_Info) {
    data, error := os2.read_entire_file_from_path(file_info.fullpath, context.temp_allocator)
    if error != nil {
        fatalf(
            .Compiler_Failed_To_Load_File,
            "failed to load file '{}' with error {}",
            file_info.fullpath, error,
        )
    }

    file_info.source = strings.clone(string(data))
}

fatalf :: proc(error: Error, format: string, args: ..any) {
    fmt.eprintf("Compiler error: ")
    fmt.eprintfln(format, ..args)
    os2.exit(int(error))
}
