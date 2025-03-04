package main

import "core:fmt"
import "core:os"
import "core:strings"

COMPILER_DATE    :: "2025-03-03"
COMPILER_EXEC    :: "skc"
COMPILER_NAME    :: "Stańczyk"
COMPILER_VERSION :: "5"

Compiler_Backend :: union {
    Compiler_Web,
}

Compiler_Web :: struct {

}

Compiler :: struct {
    backend:    Compiler_Backend,
    input:      string,
    output:     string,
    input_type: enum { directory, file },
}

skc: Compiler

main :: proc() {
    args := os.args[1:]

    if len(args) < 1 {
        fmt.println(ERROR_NO_INPUT_FILE)
        return
    }

    for i := 0; i < len(args); i += 1 {
        arg := args[i]

        switch arg {
        case "--help":
            fmt.println(MSG_HELP)
            os.exit(0)
        case "--version":
            fmt.printfln(MSG_VERSION, COMPILER_VERSION)
            os.exit(0)
        case :
            skc.input = arg
            skc.input_type = strings.ends_with(arg, ".sk") ? .file : .directory
        }
    }
}
