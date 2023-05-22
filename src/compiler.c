#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "chunk.h"
#include "common.h"
#include "compiler.h"
#include "debug.h"
#include "object.h"
#include "scanner.h"
#include "value.h"

#ifdef DEBUG_PRINT_CODE
#include "debug.h"
#endif

typedef struct {
    token_t current;
    token_t previous;
    bool erred;
    bool panic;
} parser_t;

typedef enum {
  PREC_NONE,
  PREC_EXPRESSION,  // expression literals
  PREC_OR,          // or
  PREC_AND,         // and
  PREC_EQUALITY,    // =
  PREC_COMPARISON,  // < >
  PREC_TERM,        // + -
  PREC_FACTOR,      // * /
  PREC_UNARY,       // ! -
  PREC_CALL,        // ()
  PREC_PRIMARY
} precedence_t;

typedef void (*parse_fn)();

typedef struct {
    parse_fn prefix;
    parse_fn postfix;
    precedence_t precedence;
} parse_rule_t;

typedef struct {
    token_t name;
    int depth;
} local_t;

typedef enum { TYPE_PROCEDURE, TYPE_PROGRAM } procedure_type_t;

typedef struct compiler_t compiler_t;

struct compiler_t {
    compiler_t *enclosing;
    procedure_t *procedure;
    procedure_type_t type;

    local_t locals[UINT8_COUNT];
    int local_count;
    int scope_depth;
};

parser_t parser;
compiler_t *current = NULL;
bool main_procedure_handled = false;

/*
 *    __ __    __
 *   / // /__ / /__  ___ _______
 *  / _  / -_) / _ \/ -_) __(_-<
 * /_//_/\__/_/ .__/\__/_/ /___/
 *         /_/
 * Functions that change the state of the compiler. Move through the
 * parsed code, open/close compiler instances and erroring.
 */

// Returns the chunk of code from the procedure that is compiling at this time.
static chunk_t *current_chunk() {
    return &current->procedure->chunk;
}

// Throws an error at a specific column in the code.
static void error_at(token_t *token, const char *message) {
    if (parser.panic) return;
    parser.panic = true;
    fprintf(stderr, "[line %d] Error", token->line);

    if (token->type == TOKEN_EOF) {
        fprintf(stderr, " at end");
    } else if (token->type == TOKEN_ERROR) {
        // Nothing, for now
    } else {
        fprintf(stderr, " at '%.*s'", token->length, token->start);
    }

    fprintf(stderr, ": %s\n", message);
    parser.erred = true;
}

// Helper function to error out on the specific token to be compiled
static void error(const char *message) {
    error_at(&parser.previous, message);
}

// Helper function to error out on the next token to be compiled.
static void error_at_current(const char *message) {
    error_at(&parser.current, message);
}

// Move through the code and get the token from the scanner.
static void advance() {
    parser.previous = parser.current;

    for (;;) {
        parser.current = scan_token();
        if (parser.current.type != TOKEN_ERROR) break;

        error_at_current(parser.current.start);
    }
}

// If the next token in the code matches the argument `type`, consume it and
// continue. If it doesn't match, throw an error.
// Used in expected tokens (E.g. `.` at the end of a block statement).
static void consume(token_type_t type, const char *message) {
    if (parser.current.type == type) {
        advance();
        return;
    }

    error_at_current(message);
}

// Check if the next token matches the type. Returns true or false.
static bool check(token_type_t type) {
    return parser.current.type == type;
}

// Check if the next token matches the type. If it matches, it will consume
// that token. Returns true or false.
static bool match(token_type_t type) {
    if (!check(type)) return false;
    advance();
    return true;
}

// Emit single byte code
static void emit_byte(uint8_t byte) {
    write_chunk(current_chunk(), byte, parser.previous.line);
}

// Emit double byte code
static void emit_bytes(uint8_t b1, uint8_t b2) {
    emit_byte(b1);
    emit_byte(b2);
}

// Emit usual return byte code after compiling (implicit `nil`)
static void emit_return() {
    emit_byte(OP_NIL);
    emit_byte(OP_RETURN);
}

// Creates an 8-bit constant value
static uint8_t make_constant(value_t value) {
    int constant = add_constant(current_chunk(), value);
    if (constant > UINT8_MAX) {
        error("too many constants in one chunk.");
        return 0;
    }

    return (uint8_t)constant;
}

// Creates a constant value for a string in symbols
static uint8_t symbol_constant(token_t *name) {
    return make_constant(OBJ_VAL(copy_string(name->start, name->length)));
}

// Emit the constant operation and constant value
static void emit_constant(value_t value) {
    emit_bytes(OP_CONSTANT, make_constant(value));
}

// Initialize the compiler(s). Since we compile procedures in the language, we
// open a compiler for each procedure and set the name of the procedure created
// by the user here (in case the procedure is not the top-level <PROGRAM> one)
static void init_compiler(compiler_t *compiler, procedure_type_t type) {
    compiler->enclosing = current;
    compiler->procedure = NULL;
    compiler->type = type;
    compiler->procedure = new_procedure();
    compiler->local_count = 0;
    compiler->scope_depth = 0;
    current = compiler;

    if (type != TYPE_PROGRAM) {
        current->procedure->name = copy_string(parser.previous.start, parser.previous.length);

        if (current->procedure->name->length == 4 &&
            strcmp(current->procedure->name->chars, "main") == 0)
            main_procedure_handled = true;
    }

    local_t *local = &current->locals[current->local_count++];
    local->depth = 0;
    local->name.start = "";
    local->name.length = 0;
}

// Close the compiler at hand and return the procedure generated on this compiler pass.
static procedure_t *end_compiler() {
    emit_return();
    procedure_t *procedure = current->procedure;

#ifdef DEBUG_PRINT_CODE
    if (!parser.erred)
        disassemble_chunk(current_chunk(),
                          procedure->name != NULL ? procedure->name->chars : "<PROGRAM>");
#endif

    current = current->enclosing;
    return procedure;
}

// Compare two symbols
static bool symbols_are_equal(token_t *a, token_t *b) {
    if (a->length != b->length) return false;
    return memcmp(a->start, b->start, a->length) == 0;
}

// Resolves symbols in local scope. Returns -1 if not found
static int resolve_local(compiler_t *compiler, token_t *name) {
    for (int i = compiler->local_count - 1; i >= 0; i--) {
        local_t *local = &compiler->locals[i];
        if (symbols_are_equal(name, &local->name)) {
            if (local->depth == -1)
                error("local symbol has not been initialized");
            return i;
        }
    }
    return -1;
}

// Lexical binding of the local variable
static void add_local(token_t name) {
    if (current->local_count == UINT8_COUNT) {
        error("stack overflow. Too many local symbols declared in scope.");
        return;
    }

    local_t *local = &current->locals[current->local_count++];
    local->name = name;
    local->depth = -1;
}

// Declares a symbol on the current scope. If the current scope is global (0),
// skip and continue in define_symbol.
static void declare_symbol() {
    if (current->scope_depth == 0) return;

    token_t *name = &parser.previous;
    for (int i = current->local_count - 1; i >= 0; i--) {
        local_t *local = &current->locals[i];
        if (local->depth != -1 && local->depth < current->scope_depth) break;

        if (symbols_are_equal(name, &local->name))
            error("a symbol with this name already exists in scope.");
    }

    add_local(*name);
}

// Defiens a global symbol. If it's not global but it wasn't not initialized, we
// mark it as initialized (adding the correct depth of the scope).
static void define_symbol(uint8_t global) {
    if (current->scope_depth > 0) {
        current->locals[current->local_count - 1].depth = current->scope_depth;
        return;
    }

    emit_bytes(OP_DEFINE_GLOBAL, global);
}

// Consume the next symbol in the parser, declare it (if it's local). If
// declare_symbol doesn't short-circuit, it means we're in a local scope. So
// then we leave from here because at that point the local variable is defined.
// However, if declare_symbol short-circuits, then we go and get the constant
// value for the symbol to be defined correctly.
static uint8_t parse_symbol(const char *error_message) {
    consume(TOKEN_SYMBOL, error_message);

    declare_symbol();
    if (current->scope_depth > 0) return 0;
    return symbol_constant(&parser.previous);
}

// Go deeper into the block scope. Useful for opening scopes for procedures, if/else,
// and other general blocks.
static void begin_scope() {
    current->scope_depth++;
}

// Get out of the block scope and clean up all the variables created on that scope.
static void end_scope() {
    current->scope_depth--;

    while (current->local_count > 0 &&
           current->locals[current->local_count - 1].depth > current->scope_depth) {
        // TODO: optimization. We can possibly create a multiple DROP instruction where we send
        // a second constant with the count of how many pops are needed instead of writting many
        // DROP instructions on the VM.
        // I.e. OP_DROPN, 5
        emit_byte(OP_DROP);
        current->local_count--;
    }
}

/*
 *
 *   _____                _ __     __  _
 *  / ___/__  __ _  ___  (_) /__ _/ /_(_)__  ___
 * / /__/ _ \/  ' \/ _ \/ / / _ `/ __/ / _ \/ _ \
 * \___/\___/_/_/_/ .__/_/_/\_,_/\__/_/\___/_//_/
 *               /_/
 * Functions that compile each expression and statement in the language
 */

// Forward-declaring recursive methods.
static void expression();
static parse_rule_t *get_rule(token_type_t type);
static void parse_precedence(precedence_t precedence);

static void block() {
    while(!check(TOKEN_DOT) && !check(TOKEN_EOF))
        expression();
    consume(TOKEN_DOT, "expect '.' to end block");
}

static void procedure(procedure_type_t type) {
    compiler_t compiler;
    init_compiler(&compiler, type);
    begin_scope();

    consume(TOKEN_LEFT_PAREN, "expect '(' after procedure name.");
    if (!check(TOKEN_RIGHT_PAREN)) {
        do {
            current->procedure->arity++;
            if (current->procedure->arity > 255)
                error_at_current("cannot have more than 255 parameters.");
            uint8_t symbol = parse_symbol("expect parameter name.");
            define_symbol(symbol);
        } while (match(TOKEN_COMMA));
    }
    consume(TOKEN_RIGHT_PAREN, "expect ')' after parameters.");
    consume(TOKEN_DO, "expect 'do' before procedure body.");
    block();

    procedure_t *procedure = end_compiler();
    emit_bytes(OP_CONSTANT, make_constant(OBJ_VAL(procedure)));
}

static void _neg() {
    emit_byte(OP_NEGATE);
}

static void _binary() {
    token_type_t operator_type = parser.previous.type;

    switch (operator_type) {
        case TOKEN_BANG_EQUAL:    emit_bytes(OP_EQUAL, OP_NEGATE);   break;
        case TOKEN_EQUAL_EQUAL:   emit_byte(OP_EQUAL);               break;
        case TOKEN_GREATER:       emit_byte(OP_GREATER);             break;
        case TOKEN_GREATER_EQUAL: emit_bytes(OP_LESS, OP_NEGATE);    break;
        case TOKEN_LESS:          emit_byte(OP_LESS);                break;
        case TOKEN_LESS_EQUAL:    emit_bytes(OP_GREATER, OP_NEGATE); break;
        case TOKEN_PLUS:          emit_byte(OP_ADD);                 break;
        case TOKEN_MINUS:         emit_byte(OP_SUBTRACT);            break;
        case TOKEN_STAR:          emit_byte(OP_MULTIPLY);            break;
        case TOKEN_SLASH:         emit_byte(OP_DIVIDE);              break;
        default: return;
    }
}

static void _lit() {
    switch (parser.previous.type) {
        case TOKEN_FALSE: emit_byte(OP_FALSE); break;
        case TOKEN_NIL:   emit_byte(OP_NIL);   break;
        case TOKEN_TRUE:  emit_byte(OP_TRUE);  break;
        default: return;
    }
}

static void _number() {
    token_type_t type = parser.previous.type;

    switch (type) {
        case TOKEN_VALUE_INT: {
            long value = strtol(parser.previous.start, NULL, 10);
            emit_constant(INT_VAL(value));
        } break;
        case TOKEN_VALUE_FLOAT: {
            double value = strtod(parser.previous.start, NULL);
            emit_constant(FLOAT_VAL(value));
        } break;
        default: return;
    }

}

static void _string() {
    emit_constant(OBJ_VAL(copy_string(parser.previous.start + 1, parser.previous.length - 2)));
}

static void named_symbol(token_t name, bool assignment) {
    uint8_t get_op, set_op;
    int arg = resolve_local(current, &name);

    if (arg != -1) {
        get_op = OP_GET_LOCAL;
        set_op = OP_SET_LOCAL;
    } else {
        arg = symbol_constant(&name);
        get_op = OP_GET_GLOBAL;
        set_op = OP_SET_GLOBAL;
    }

    emit_bytes(assignment ? set_op : get_op, (uint8_t)arg);
}

static void _symbol() {
    token_t name = parser.previous;

    named_symbol(name, false);

    if (match(TOKEN_PLUS_PLUS)) {
        emit_constant(INT_VAL(1));
        emit_byte(OP_ADD);
        named_symbol(name, true);
        emit_byte(OP_DROP);
    } else if (match(TOKEN_MINUS_MINUS)) {
        emit_constant(INT_VAL(1));
        emit_byte(OP_SUBTRACT);
        named_symbol(name, true);
        emit_byte(OP_DROP);
    }
}

static void _stmt()  {
    token_type_t statement_type = parser.previous.type;

    switch (statement_type) {
        case TOKEN_AT:           emit_byte(OP_CAST);  break;
        case TOKEN_PRINT:        emit_byte(OP_PRINT); break;
        case TOKEN_DO: {
            begin_scope();
            block();
            end_scope();
        } break;
        case TOKEN_DROP:         emit_byte(OP_DROP);  break;
        case TOKEN_DUP:          emit_byte(OP_DUP);   break;
        case TOKEN_LESS_GREATER: emit_byte(OP_SPLIT); break;
        case TOKEN_GREATER_LESS: emit_byte(OP_JOIN);  break;
        default: return;
    }
}

// TODO: Add description to this and all the other methods, good documentation
// of these functions will help me go through this in the future.
// This function basically gets the next expression happening while defining or
// assigning something to a symbol.
static void find_and_emit_value() {
    if (match(TOKEN_DOT)) {
        emit_byte(OP_NIL);
    } else {
        while(!check(TOKEN_DOT) && !check(TOKEN_EOF))
            expression();
        consume(TOKEN_DOT, "expect '.' after symbol declaration.");
    }
}

static void _assign() {
    consume(TOKEN_SYMBOL, "expect symbol name after '='");
    token_t name = parser.previous;
    find_and_emit_value();
    named_symbol(name, true);
}

static void _symbol_declare() {
    uint8_t symbol = parse_symbol("expect symbol name after ':='");
    find_and_emit_value();
    define_symbol(symbol);
}

static void _procedure_declare() {
    uint8_t symbol = parse_symbol("expect procedure name after '::'");
    // TODO: Figure out if I need to mark it mark_initialized();
    procedure(TYPE_PROCEDURE);
    define_symbol(symbol);
}

static void _declare() {
    if (match(TOKEN_EQUAL)) {
        // variable declaration with type inference
        _symbol_declare();
    } else if (match(TOKEN_COLON)) {
        _procedure_declare();
    } else {
        error("failed to declare symbol or procedure.");
        error("missing '=' or ':'.");
        return;
    }
}

static int emit_jump(uint8_t instruction) {
    emit_byte(instruction);
    emit_byte(0xff);
    emit_byte(0xff);
    return current_chunk()->count - 2;
}

static void patch_jump(int offset) {
    int jump = current_chunk()->count - offset - 2;

    if (jump > UINT16_MAX)
        error("too much code to make the jump");

    current_chunk()->code[offset] = (jump >> 8) & 0xff;
    current_chunk()->code[offset + 1] = jump & 0xff;
}

static void _if() {
    int else_jump, then_jump;
    then_jump = emit_jump(OP_JUMP_IF_FALSE);
    emit_byte(OP_DROP);

    begin_scope();
    while (!check(TOKEN_DOT) && !check(TOKEN_ELSE) && !check(TOKEN_EOF))
        expression();

    end_scope();

    else_jump = emit_jump(OP_JUMP);
    patch_jump(then_jump);
    emit_byte(OP_DROP);

    if (match(TOKEN_ELSE)) {
        begin_scope();
        while (!match(TOKEN_DOT) && !match(TOKEN_EOF))
            expression();
        end_scope();
    } else {
        consume(TOKEN_DOT, "expect '.' after if block");
    }
    patch_jump(else_jump);
}

static void _logical() {
    token_type_t operator_type = parser.previous.type;

    switch (operator_type) {
        case TOKEN_AND: emit_byte(OP_AND); break;
        case TOKEN_OR:  emit_byte(OP_OR); break;
        default: return;
    }
}

static void emit_loop(int loop_start) {
    emit_byte(OP_LOOP);

    int offset = current_chunk()->count - loop_start + 2;
    if (offset > UINT16_MAX) error("loop body is too large.");

    emit_byte((offset >> 8) & 0xff);
    emit_byte(offset & 0xff);
}

static void _loop() {
    int exit_jump, loop_start, quit_jump;
    bool omit_declaration = false;

    begin_scope();
    loop_start = current_chunk()->count;
    quit_jump = -1;

    if (match(TOKEN_RIGHT_BRACE)) {
        // Case 1: Implicit true for infinite loops // {} do
        emit_byte(OP_TRUE);
        omit_declaration = true;
    }

    // TODO: This rewrite can be done once I change the algorithm to parse
    // else if (match(TOKEN_VALUE_INT)) {
    //     // Take the first number value
    //     _number();
    //     // User defined a number for the first parameter, we look into what's next.
    //     // If it's another number, we continue with the evaluation.

    //     if (match(TOKEN_DOT_DOT)) {

    //     }

    // }
    // } else if (match(TOKEN_COLON)) {
    //     // Case 2: Lexical binding of index inside this scope
    //     consume(TOKEN_EQUAL, "expect '=' for variable definition.");

    //     if (check(TOKEN_SYMBOL)) {
    //         // The user picked an specific name for the symbol := // {:= myvar 0 3 ==} do
    //     } else {
    //         // The user didn't picked an specific name, so we bind 'i' // {:= 0 3 ==}

    //     }
    // }

    if (!omit_declaration) {
        while (!check(TOKEN_RIGHT_BRACE) && !check(TOKEN_EOF))
            expression();
        consume(TOKEN_RIGHT_BRACE, "expect '}' at the end of conditionals for loop");
    }

    consume(TOKEN_DO, "expect 'do' at the start of the loop");

    exit_jump = emit_jump(OP_JUMP_IF_FALSE);
    emit_byte(OP_DROP);

    // Parse body of loop
    while (!check(TOKEN_DOT) && !check(TOKEN_EOF)) {
        expression();
        if (match(TOKEN_QUIT)) {
            // Emits the quit jump that only works on loops, but also, it drops the
            // previous expression because we want to allow quit only if the stack has
            // a boolean value.
            quit_jump = emit_jump(OP_QUIT);
            emit_byte(OP_DROP);
        }
    }
    consume(TOKEN_DOT, "expect '.' after loop");
    end_scope();

    emit_loop(loop_start);
    patch_jump(exit_jump);
    if (quit_jump != -1)
        patch_jump(quit_jump);
    emit_byte(OP_DROP);
}

static void _quit() {
    error("cannot 'quit' on this context");
}

static uint8_t argument_list() {
    uint8_t arg_count = 0;
    if (!check(TOKEN_RIGHT_PAREN)) {
        do {
            while (!check(TOKEN_COMMA) && !check(TOKEN_EOF) && !check(TOKEN_RIGHT_PAREN))
                expression();

            if (arg_count == 255)
                error("cannot have more than 255 arguments");

            arg_count++;

            if (check(TOKEN_EOF)) {
                error("incomplete procedure.");
                break;
            }
        } while (match(TOKEN_COMMA));
    }

    consume(TOKEN_RIGHT_PAREN, "expect ')' after arguments.");
    return arg_count;
}

static void _call() {
    uint8_t arg_count = argument_list();
    emit_bytes(OP_CALL, arg_count);
}

static void _return() {
    if (current->type == TYPE_PROGRAM)
        error("cannot return value in this context.");

    emit_byte(OP_RETURN);
}

static void _list() {
    int count = 0;

    if (!check(TOKEN_RIGHT_BRACKET)) {
        do {
            while (!check(TOKEN_COMMA) && !check(TOKEN_EOF) && !check(TOKEN_RIGHT_BRACKET))
                expression();

            if (count == 255)
                error("cannot have more than 255 items");

            count++;
        } while (match(TOKEN_COMMA));
    }

    consume(TOKEN_RIGHT_BRACKET, "expect ']' after list literal.");
    emit_bytes(OP_LIST_CREATE, count);
}

static void _access() {
    while (!check(TOKEN_EOF) && !check(TOKEN_RIGHT_BRACKET))
        expression();

    consume(TOKEN_RIGHT_BRACKET, "expect ']' after index.");

    emit_byte(OP_LIST_GET_INDEX);
}

// Type declaration
static void _tdclr() {
    token_type_t type = parser.previous.type;

    switch (type) {
        case TOKEN_TYPE_LIST:   emit_constant(TYPE_DECL_VAL(TYPE_LIST));  break;
        case TOKEN_TYPE_STRING: emit_constant(TYPE_DECL_VAL(TYPE_STR));   break;
        case TOKEN_TYPE_FLOAT:  emit_constant(TYPE_DECL_VAL(TYPE_FLOAT)); break;
        case TOKEN_TYPE_INT:    emit_constant(TYPE_DECL_VAL(TYPE_INT));   break;
        default: return;
    }
}

parse_rule_t rules[] = {
    [TOKEN_LEFT_PAREN]    = {NULL,        _call,      PREC_CALL},
    [TOKEN_RIGHT_PAREN]   = {NULL,        NULL,       PREC_NONE},
    [TOKEN_LEFT_BRACE]    = {_loop,       NULL,       PREC_NONE},
    [TOKEN_RIGHT_BRACE]   = {NULL,        NULL,       PREC_NONE},
    [TOKEN_LEFT_BRACKET]  = {_list,       _access,    PREC_CALL},
    [TOKEN_RIGHT_BRACKET] = {NULL,        NULL,       PREC_NONE},
    [TOKEN_COMMA]         = {NULL,        NULL,       PREC_NONE},
    [TOKEN_EQUAL]         = {_assign,     NULL,       PREC_NONE},
    [TOKEN_COLON]         = {_declare,    NULL,       PREC_NONE},
    [TOKEN_MINUS]         = {NULL,        _binary,    PREC_TERM},
    [TOKEN_PLUS]          = {NULL,        _binary,    PREC_TERM},
    [TOKEN_SLASH]         = {NULL,        _binary,    PREC_FACTOR},
    [TOKEN_STAR]          = {NULL,        _binary,    PREC_FACTOR},
    [TOKEN_BANG_EQUAL]    = {NULL,        _binary,    PREC_EQUALITY},
    [TOKEN_EQUAL_EQUAL]   = {NULL,        _binary,    PREC_EQUALITY},
    [TOKEN_GREATER]       = {NULL,        _binary,    PREC_EQUALITY},
    [TOKEN_GREATER_EQUAL] = {NULL,        _binary,    PREC_EQUALITY},
    [TOKEN_LESS]          = {NULL,        _binary,    PREC_EQUALITY},
    [TOKEN_LESS_EQUAL]    = {NULL,        _binary,    PREC_EQUALITY},
    [TOKEN_SYMBOL]        = {_symbol,     NULL,       PREC_NONE},
    [TOKEN_VALUE_STRING]  = {_string,     NULL,       PREC_NONE},
    [TOKEN_VALUE_FLOAT]   = {_number,     NULL,       PREC_NONE},
    [TOKEN_VALUE_INT]     = {_number,     NULL,       PREC_NONE},
    [TOKEN_FALSE]         = {_lit,        NULL,       PREC_NONE},
    [TOKEN_TRUE]          = {_lit,        NULL,       PREC_NONE},
    [TOKEN_NIL]           = {_lit,        NULL,       PREC_NONE},
    [TOKEN_IF]            = {_if,         NULL,       PREC_NONE},
    [TOKEN_AND]           = {NULL,        _logical,   PREC_AND},
    [TOKEN_OR]            = {NULL,        _logical,   PREC_OR},
    [TOKEN_DO]            = {_stmt,       NULL,       PREC_NONE},
    [TOKEN_PRINT]         = {_stmt,       NULL,       PREC_NONE},
    [TOKEN_DROP]          = {_stmt,       NULL,       PREC_NONE},
    [TOKEN_DUP]           = {_stmt,       NULL,       PREC_NONE},
    [TOKEN_AT]            = {_stmt,       NULL,       PREC_NONE},
    [TOKEN_LESS_GREATER]  = {_stmt,       NULL,       PREC_NONE},
    [TOKEN_GREATER_LESS]  = {_stmt,       NULL,       PREC_NONE},
    [TOKEN_BANG]          = {NULL,        _return,    PREC_CALL},
    [TOKEN_NEG]           = {_neg,        NULL,       PREC_NONE},
    [TOKEN_QUIT]          = {_quit,       NULL,       PREC_NONE},
    [TOKEN_TYPE_LIST]     = {_tdclr,      NULL,       PREC_NONE},
    [TOKEN_TYPE_STRING]   = {_tdclr,      NULL,       PREC_NONE},
    [TOKEN_TYPE_FLOAT]    = {_tdclr,      NULL,       PREC_NONE},
    [TOKEN_TYPE_INT]      = {_tdclr,      NULL,       PREC_NONE},
    [TOKEN_ERROR]         = {NULL,        NULL,       PREC_NONE},
    [TOKEN_EOF]           = {NULL,        NULL,       PREC_NONE}
};

// TODO: This is using Vaughan Pratt's top-down operator precedence parser
// method, but technically we don't need it. MAYBE: Find a better parser that
// works well with reverse polish notation, since at the time we generate the
// bytecode, our language pretty much is following the same structure.
static void parse_precedence(precedence_t precedence) {
    advance();
    parse_fn prefix_rule = get_rule(parser.previous.type)->prefix;

    if (prefix_rule == NULL) {
        error("expect expression.");
        return;
    }

    prefix_rule();

    while (precedence <= get_rule(parser.current.type)->precedence) {
        advance();
        parse_fn postfix_rule = get_rule(parser.previous.type)->postfix;
        postfix_rule();
    }
}

static parse_rule_t *get_rule(token_type_t type) {
    return &rules[type];
}

static void expression() {
    parse_precedence(PREC_EXPRESSION);
}

static void synchronize() {
    parser.panic = false;

    // TODO: Disabling panic mode should only work for specific context.
    // We want to skip over the possibles erred statements and continue compiling after that,
    // so we can catch errors (if any) in the following procedures.
    // Right now we disable panic after any statement.
}

static void add_main_call() {
    uint8_t main_procedure = make_constant(OBJ_VAL(copy_string("main", 4)));
    emit_bytes(OP_GET_GLOBAL, main_procedure);
    emit_bytes(OP_CALL, 0);
}

procedure_t *compile(const char *source) {
    compiler_t compiler;
    init_scanner(source);
    init_compiler(&compiler, TYPE_PROGRAM);

    parser.erred = false;
    parser.panic = false;

    advance();
    while (!match(TOKEN_EOF)) {
        expression();
        if (parser.panic) synchronize();
    }

    if (!main_procedure_handled) {
        error("need to define a 'main' procedure as the entry point");
        return NULL;
    }

    add_main_call();

    procedure_t *procedure = end_compiler();
    return parser.erred ? NULL : procedure;
}
