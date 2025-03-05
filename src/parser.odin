package main

import "core:log"

Op_Push_Integer :: struct {
    value: int,
}

Op_Push_String :: struct {
    value: string,
}

Op_Print :: struct {}

Op_Repl_Exit :: struct {}

Operation_Kind :: union {
    Op_Push_Integer,
    Op_Push_String,

    Op_Print,

    Op_Repl_Exit,
}

Operation :: struct {
    kind: Operation_Kind,
    loc: struct {
        file: string,
        offset: int,
    },
}

parse_tokens :: proc(tokens: []Token) {
    for token in tokens {
        switch token.kind {
        case .Invalid:
            log.errorf(ERROR_INVALID_TOKEN, token)
        case .Comment:
            // Note: Skipping the comment tokens for now, but might be interesting to
            // keep them around in case we're able to use them.
        case .EOF:
            // This marks the end of the loop, should always be at the end of the file.

        case .Identifier:
            unimplemented()
            // TODO: Should create whatever it is trying to do
        case .Integer: unimplemented()
        case .Float: unimplemented()
        case .Character: unimplemented()
        case .String: unimplemented()

        case .Colon_Colon: unimplemented()
        case .Minus: unimplemented()
        case .Paren_Left: unimplemented()
        case .Paren_Right: unimplemented()
        case .Plus: unimplemented()
        case .Semicolon: unimplemented()
        case .Slash: unimplemented()
        case .Star: unimplemented()
        case .Keyword_Asm: unimplemented()
        case .Keyword_Print: unimplemented()
        case .Keyword_Using: unimplemented()

        case .Dot_Exit:
            if compiler_mode == .REPL {
                append(&program, Operation{
                    kind = Op_Repl_Exit{},
                    loc  = {
                        file   = token.file,
                        offset = token.start,
                    },
                })
            }
        }
    }
}

parse_files :: proc() {
    for filepath, source in source_files {
        tokens := tokenize(source, filepath)
        parse_tokens(tokens)
        free_all(context.temp_allocator)
    }
}
