package main

import "core:os"
import "core:strings"

EntryTypeGiven :: enum { DIR, FILE, }

CompilerArguments :: struct {
    entry: string,
    entry_type_given: EntryTypeGiven,
    output_filename: string,
}

compiler_args: CompilerArguments

main :: proc() {
    if len(os.args) == 1 {
        // TODO: Add correct error message
        return
    }

    // Setting defaults
    compiler_args.output_filename = "out.exe" // TODO: This should change to match OS

    for i := 1; i < len(os.args); i += 1 {
        argument := os.args[i]

        if i == 1 {
            if strings.contains(argument, ".sk") {
                compiler_args.entry_type_given = .FILE
            } else if argument == "" {
                // TODO: Handle error for missign entry file, with a throw
                return
            } else {
                compiler_args.entry_type_given = .DIR
            }

            compiler_args.entry = argument
            continue
        }

        if argument == "-out" {
            if i + 1 > len(os.args) {
                // TODO: ERROR
            }

            i += 1
            argument = os.args[i]

            compiler_args.output_filename = argument
            continue
        }
    }

    setup_and_run_scanner()
}
