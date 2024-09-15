package main

import "core:fmt"
import "core:os"

errors := map[string]string{
    "TOKENIZER__CANNOT_OPEN_DIR" = "Can't open directory `{0}`. Error: {1}",
    "TOKENIZER__CANNOT_OPEN_FILE" = "Can't open file `{0}`.",
    "TOKENIZER__CANNOT_READ_DIR" = "Can't read directory `{0}`. Error: {1}",
    "TOKENIZER__NO_FILES_FOUND" = "No files found on directory `{0}`.",
    "TOKENIZER__NOT_A_DIR" = "Directory `{0}` not found.",
    "TOKENIZER__NOT_A_FILE" = "File `{0}` not found or is not an actual file.",
}

Panic_Error_Code :: enum {
    NONE = 0,
    PARSER,
}

// This is only used when the error on one of the steps of the compilation is too hard to handle.
// Usually, I don't want to panic the execution so the user knows of all the possible errors on
// their code and can fix them at once, but if the error could break the whole compilation, then
// it's safer to just panic out.
panic_execution :: proc(ecode: Panic_Error_Code) {
    code := int(ecode)
    print_all_compiler_errors()
    fmt.printfln("\nExited with error code {0}", code)
    os.exit(code)
}

error_at_tokenizer :: proc(err_key: string, rest: ..any) {
    new_err := fmt.aprintf(errors[err_key], ..rest)
    append(&program.errors, new_err)
    panic_execution(.PARSER)
}

get_error_message :: proc(err: string, rest: ..any) -> string {
    return fmt.aprintf(errors[err], ..rest)
}
