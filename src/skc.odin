package main

import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"
import "core:time"

NAME          :: "Stańczyk"
NAME_ABBREV   :: "skc"
NAME_FULL     :: "The Stańczyk Compiler"
VERSION_MAJOR :: "0"
VERSION_MINOR :: "7"

Fatal_Error_Kind :: enum u8 {
    None      = 0,
    Compiler  = 1,
    Parser    = 2,
    Checker   = 3,
    Generator = 4,
}

Compiler_Error :: struct {
    message: string,
    token:   Token,
}

File_Info :: struct {
    short_name:  string,
    filename:    string,
    fullpath:    string,
    source:      string,
    line_starts: [dynamic]int,
}

compiler_dir:      string
working_dir:       string
output_filename:   string
total_lines_count: int
source_files:      [dynamic]File_Info
program_bytecode:  [dynamic]^Op_Code
program_ast:       [dynamic]^Ast

// Defaults
switch_debug := true

main :: proc() {
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
    output_filename = fmt.aprintf("{}.c", input_filename[:len(input_filename)-len(extension)])

    init_types()


    accumulator := time.tick_now()
    add_source_file(working_dir, os.args[1])
    for &file_info in source_files {
        load_entire_file(&file_info)
        parse_file(&file_info)
    }

    free_all(context.temp_allocator)
    print_magenta("\t[Lines processed]     ")
    fmt.printfln("{}", total_lines_count)

    check_program_bytecode()
    print_magenta("\t[Compiler Front-end]  ")
    fmt.printfln("%.6fms", time.duration_milliseconds(time.tick_lap_time(&accumulator)))

    gen_program()
    print_magenta("\t[Code generation]     ")
    fmt.printfln("%.6fms", time.duration_milliseconds(time.tick_lap_time(&accumulator)))

    fmt.printfln("\n========\n")
    for op, index in program_bytecode do print_op_debug(op)
    fmt.printfln("========\n")
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

fatalf :: proc(error: Fatal_Error_Kind, format: string, args: ..any) {
    fmt.eprintln()
    error_red("{} Error: ", error)
    fmt.eprintfln(format, ..args)
    fmt.eprintln()
    os2.exit(int(error))
}

error_red :: proc(format: string, args: ..any) {
    message := fmt.tprintf(format, ..args)
    fmt.eprintf("\e[1;91m{}\e[0m", message)
}

print_magenta :: proc(format: string, args: ..any) {
    message := fmt.tprintf(format, ..args)
    fmt.printf("\e[1;95m{}\e[0m", message)
}

report_all_errors :: proc(comp_errors: []Compiler_Error) {
    line_number_to_string :: proc(number: int) -> string {
        number_str := fmt.tprintf("{}", number)
        return strings.right_justify(number_str, 4, " ")
    }

    for error in comp_errors {
        token := error.token
        fullpath := token.file_info.fullpath
        line_starts := token.file_info.line_starts
        source := token.file_info.source

        fmt.eprintfln(
            "\e[1m{}({}:{})\e[1;91m Error:\e[0m {}",
            fullpath, token.l0, token.c0, error.message,
        )
        fmt.eprint("\e[0;36m")
        if token.l0 > 1 {
            line_index := max(token.l0-2, 0)
            count_of_chars := 0
            for line_index > 0 && count_of_chars == 0 {
                start := line_starts[line_index]
                end := line_starts[line_index+1] - 1
                count_of_chars = end - start
                if count_of_chars == 0 do line_index -= 1
            }
            line_index = max(line_index, 0)
            start := line_starts[line_index]
            text := source[start:token.start]
            token_start_index := token.start - start

            fmt.eprintf("\t{} | \t", line_number_to_string(line_index + 1))
            for r, index in text {
                fmt.eprint(r)

                if r == '\n' {
                    line_index += 1
                    fmt.eprintf("\t{} | \t", line_number_to_string(line_index + 1))
                }
            }

            error_red(source[token.start:token.end])
        } else {
            curr_line := source[:token.start]
            fmt.eprintf("\t{} | \t{}", line_number_to_string(token.l0), curr_line)
            error_red(source[token.start:token.end])
        }

        fmt.eprint("\e[0m\n")
    }
}
