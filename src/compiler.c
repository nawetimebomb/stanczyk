#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "chunk.h"
#include "common.h"
#include "compiler.h"
#include "memory.h"
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

typedef void (*parse_fn)(bool);

typedef enum {
    SKIPPED,
    LITERAL_INT,
    LITERAL_FLOAT,
    LITERAL_STRING,
    LITERAL_LIST,
    LITERAL_BOOL,
    LITERAL_NIL,
    LOGICAL_AND,
    LOGICAL_OR,
    PROCEDURE_CALL,
    START_LOOP,
    ASSIGN_SYMBOL,
    DECLARE_SYMBOL,
    FIND_SYMBOL,
    BINARY_OP_SUBSTRACT,
    BINARY_OP_ADD,
    BINARY_OP_DIVIDE,
    BINARY_OP_MULTIPLY,
    BINARY_OP_NOT_EQUAL,
    BINARY_OP_EQUAL,
    BINARY_OP_GREATER,
    BINARY_OP_GREATER_EQUAL,
    BINARY_OP_LESS,
    BINARY_OP_LESS_EQUAL,
    IF_BLOCK,
    INTRINSIC_DO,
    INTRINSIC_PRINT,
    INTRINSIC_DROP,
    INTRINSIC_DUP,
    INTRINSIC_SPLIT,
    INTRINSIC_JOIN,
    UNARY_RETURN,
    UNARY_NEGATE,
    UNARY_QUIT,
} expr_eval_t;

typedef struct {
    parse_fn func;
    expr_eval_t expr;
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
const char *filename = "";

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
    fprintf(stderr, "%s:%d:%d: ERROR", filename, token->line, token->column);

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
static expr_eval_t expression(bool skip_global_check);
static parse_rule_t *get_rule(token_type_t type);
static expr_eval_t parse_next(bool skip_global_check);

static void block() {
    while(!check(TOKEN_DOT) && !check(TOKEN_EOF))
        expression(false);
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

// TODO: Add description to this and all the other methods, good documentation
// of these functions will help me go through this in the future.
// This function basically gets the next expression happening while defining or
// assigning something to a symbol.
static void find_and_emit_value() {
    if (match(TOKEN_DOT)) {
        emit_byte(OP_NIL);
    } else {
        while(!check(TOKEN_DOT) && !check(TOKEN_EOF))
            expression(true);
        consume(TOKEN_DOT, "expect '.' after symbol declaration.");
    }
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

static void emit_loop(int loop_start) {
    emit_byte(OP_LOOP);

    int offset = current_chunk()->count - loop_start + 2;
    if (offset > UINT16_MAX) error("loop body is too large.");

    emit_byte((offset >> 8) & 0xff);
    emit_byte(offset & 0xff);
}

static uint8_t argument_list(bool global_allow_override) {
    uint8_t arg_count = 0;
    if (!check(TOKEN_RIGHT_PAREN)) {
        do {
            while (!check(TOKEN_COMMA) && !check(TOKEN_EOF) && !check(TOKEN_RIGHT_PAREN))
                expression(global_allow_override);

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

static void emit_list_get_index(bool global_allow_override) {
    while (!check(TOKEN_EOF) && !check(TOKEN_RIGHT_BRACKET))
        expression(global_allow_override);

    consume(TOKEN_RIGHT_BRACKET, "expect ']' after index when trying to access list.");

    emit_byte(OP_LIST_GET_INDEX);
}

/* Check if the current compiling context is the global scope and if it
 * should not allow to run the rule expression */
static bool disallowed_in_global_scope(bool global_allow_override) {
    return current->type == TYPE_PROGRAM && !global_allow_override;
}

/* Numeric costant evaluation */
static void RULE_number(bool global_allow_override) {
    if (disallowed_in_global_scope(global_allow_override)) {
        error("numeric constant not allowed in global scope.");
        return;
    }

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

/* String literal evaluation */
static void RULE_string(bool global_allow_override) {
    if (disallowed_in_global_scope(global_allow_override)) {
        error("string literal not allowed in global scope.");
        return;
    }
    emit_constant(OBJ_VAL(copy_string(parser.previous.start + 1, parser.previous.length - 2)));
}

/* Nil and Boolean literal evaluation */
static void RULE_bool_lit(bool global_allow_override) {
    if (disallowed_in_global_scope(global_allow_override)) {
        if (TOKEN_NIL) {
            error("nil not allowed in global scope.");
        } else {
            error("Boolean literal not allowed in global scope.");
        }
        return;
    }

    switch (parser.previous.type) {
        case TOKEN_FALSE: emit_byte(OP_FALSE); break;
        case TOKEN_NIL:   emit_byte(OP_NIL);   break;
        case TOKEN_TRUE:  emit_byte(OP_TRUE);  break;
        default: return;
    }
}

/* Binary operations evaluation */
static void RULE_binary(bool global_allow_override) {
    if (disallowed_in_global_scope(global_allow_override)) {
        error("binary operation not allowed in global scope.");
        return;
    }

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

/* Intrinsics evaluation */
static void RULE_intrinsics(bool global_allow_override)  {
    if (disallowed_in_global_scope(global_allow_override)) {
        error("statement not allowed in global scope.");
        return;
    }

    token_type_t statement_type = parser.previous.type;

    switch (statement_type) {
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

/* Logical operator evaluation */
static void RULE_logical(bool global_allow_override) {
    if (disallowed_in_global_scope(global_allow_override)) {
        error("logical operator not allowed in global scope.");
        return;
    }

    token_type_t operator_type = parser.previous.type;

    switch (operator_type) {
        case TOKEN_AND: emit_byte(OP_AND); break;
        case TOKEN_OR:  emit_byte(OP_OR); break;
        default: return;
    }
}

/* Return evaluation */
static void RULE_return(bool global_allow_override) {
    // We force the check to fail because we don't allow to return in the global scope.
    if (disallowed_in_global_scope(false)) {
        error("return statement not allowed in global scope.");
        return;
    }

    emit_byte(OP_RETURN);
}

/* Negate values (Booleans and numbers) */
static void RULE_neg(bool global_allow_override) {
    if (disallowed_in_global_scope(global_allow_override)) {
        error("'neg' keyword not allowed in global scope.");
        return;
    }

    emit_byte(OP_NEGATE);
}

/* Quiting from loops */
static void RULE_quit(bool global_allow_override) {
    error("cannot 'quit' in this context");
    return;
}

/* Symbol find and re-assign if incrementing or decrementing */
static void RULE_symbol(bool global_allow_override) {
    if (disallowed_in_global_scope(global_allow_override)) {
        error("symbol cannot be used in global scope.");
        return;
    }

    token_t name = parser.previous;

    named_symbol(name, false);

    if (match(TOKEN_PLUS_PLUS)) {
        emit_constant(INT_VAL(1));
        emit_byte(OP_ADD);
        named_symbol(name, true);
    } else if (match(TOKEN_MINUS_MINUS)) {
        emit_constant(INT_VAL(1));
        emit_byte(OP_SUBTRACT);
        named_symbol(name, true);
    } else if (match(TOKEN_LEFT_BRACKET)) {
        emit_list_get_index(global_allow_override);
    }
}

/* If blocks */
static void RULE_if(bool global_allow_override) {
    if (disallowed_in_global_scope(global_allow_override)) {
        error("if statements not allowed in global scope.");
        return;
    }

    int else_jump, then_jump;
    then_jump = emit_jump(OP_JUMP_IF_FALSE);
    emit_byte(OP_DROP);

    begin_scope();
    while (!check(TOKEN_DOT) && !check(TOKEN_ELSE) && !check(TOKEN_EOF))
        expression(global_allow_override);

    end_scope();

    else_jump = emit_jump(OP_JUMP);
    patch_jump(then_jump);
    emit_byte(OP_DROP);

    if (match(TOKEN_ELSE)) {
        begin_scope();
        while (!match(TOKEN_DOT) && !match(TOKEN_EOF))
            expression(global_allow_override);
        end_scope();
    } else {
        consume(TOKEN_DOT, "expect '.' after if block");
    }
    patch_jump(else_jump);
}

/* Declaring symbols */
static void RULE_declare(bool global_allow_override) {
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

/* Assigning new values to symbols */
static void RULE_assign(bool global_allow_override) {
    consume(TOKEN_SYMBOL, "expect symbol name after '='");
    token_t name = parser.previous;
    find_and_emit_value();
    named_symbol(name, true);
}

/* List literal evaluation */
static void RULE_list(bool global_allow_override) {
    if (disallowed_in_global_scope(global_allow_override)) {
        error("list literal not allowed in global scope.");
        return;
    }

    int count = 0;

    if (!check(TOKEN_RIGHT_BRACKET)) {
        do {
            while (!check(TOKEN_COMMA) && !check(TOKEN_EOF) && !check(TOKEN_RIGHT_BRACKET))
                expression(global_allow_override);

            if (count == 255)
                error("cannot have more than 255 items");

            count++;
        } while (match(TOKEN_COMMA));
    }

    consume(TOKEN_RIGHT_BRACKET, "expect ']' after list literal.");
    emit_bytes(OP_LIST_CREATE, count);
}

/* Loop creation */
static void RULE_loop(bool global_allow_override) {
    if (disallowed_in_global_scope(global_allow_override)) {
        error("loop not allowed in global scope.");
        return;
    }

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
            expression(global_allow_override);
        consume(TOKEN_RIGHT_BRACE, "expect '}' at the end of conditionals for loop");
    }

    consume(TOKEN_DO, "expect 'do' at the start of the loop");

    exit_jump = emit_jump(OP_JUMP_IF_FALSE);
    emit_byte(OP_DROP);

    // Parse body of loop
    while (!check(TOKEN_DOT) && !check(TOKEN_EOF)) {
        expression(global_allow_override);
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

/* Procedure call */
static void RULE_call(bool global_allow_override) {
    if (disallowed_in_global_scope(global_allow_override)) {
        error("procedure call not allowed in global scope.");
        return;
    }

    uint8_t arg_count = argument_list(global_allow_override);
    emit_bytes(OP_CALL, arg_count);
}


parse_rule_t rules[] = {
    [TOKEN_LEFT_PAREN]    = {RULE_call,       PROCEDURE_CALL},
    [TOKEN_LEFT_BRACE]    = {RULE_loop,       START_LOOP},
    [TOKEN_LEFT_BRACKET]  = {RULE_list,       LITERAL_LIST},
    [TOKEN_EQUAL]         = {RULE_assign,     ASSIGN_SYMBOL},
    [TOKEN_COLON]         = {RULE_declare,    DECLARE_SYMBOL},
    [TOKEN_MINUS]         = {RULE_binary,     BINARY_OP_SUBSTRACT},
    [TOKEN_PLUS]          = {RULE_binary,     BINARY_OP_ADD},
    [TOKEN_SLASH]         = {RULE_binary,     BINARY_OP_DIVIDE},
    [TOKEN_STAR]          = {RULE_binary,     BINARY_OP_MULTIPLY},
    [TOKEN_BANG_EQUAL]    = {RULE_binary,     BINARY_OP_NOT_EQUAL},
    [TOKEN_EQUAL_EQUAL]   = {RULE_binary,     BINARY_OP_EQUAL},
    [TOKEN_GREATER]       = {RULE_binary,     BINARY_OP_GREATER},
    [TOKEN_GREATER_EQUAL] = {RULE_binary,     BINARY_OP_GREATER_EQUAL},
    [TOKEN_LESS]          = {RULE_binary,     BINARY_OP_LESS},
    [TOKEN_LESS_EQUAL]    = {RULE_binary,     BINARY_OP_LESS_EQUAL},
    [TOKEN_SYMBOL]        = {RULE_symbol,     FIND_SYMBOL},
    [TOKEN_VALUE_STRING]  = {RULE_string,     LITERAL_STRING},
    [TOKEN_VALUE_FLOAT]   = {RULE_number,     LITERAL_FLOAT},
    [TOKEN_VALUE_INT]     = {RULE_number,     LITERAL_INT},
    [TOKEN_FALSE]         = {RULE_bool_lit,   LITERAL_BOOL},
    [TOKEN_TRUE]          = {RULE_bool_lit,   LITERAL_BOOL},
    [TOKEN_NIL]           = {RULE_bool_lit,   LITERAL_NIL},
    [TOKEN_IF]            = {RULE_if,         IF_BLOCK},
    [TOKEN_AND]           = {RULE_logical,    LOGICAL_AND},
    [TOKEN_OR]            = {RULE_logical,    LOGICAL_OR},
    [TOKEN_DO]            = {RULE_intrinsics, INTRINSIC_DO},
    [TOKEN_PRINT]         = {RULE_intrinsics, INTRINSIC_PRINT},
    [TOKEN_DROP]          = {RULE_intrinsics, INTRINSIC_DROP},
    [TOKEN_DUP]           = {RULE_intrinsics, INTRINSIC_DUP},
    [TOKEN_LESS_GREATER]  = {RULE_intrinsics, INTRINSIC_SPLIT},
    [TOKEN_GREATER_LESS]  = {RULE_intrinsics, INTRINSIC_JOIN},
    [TOKEN_BANG]          = {RULE_return,     UNARY_RETURN},
    [TOKEN_NEG]           = {RULE_neg,        UNARY_NEGATE},
    [TOKEN_QUIT]          = {RULE_quit,       UNARY_QUIT},
};

static parse_rule_t *get_rule(token_type_t type) {
    return &rules[type];
}

static expr_eval_t parse_next(bool skip_global_check) {
    advance();
    parse_rule_t *rule = get_rule(parser.previous.type);

    if (rule->func == NULL) {
        error("expect expression.");
        return SKIPPED;
    }

    rule->func(skip_global_check);
    return rule->expr;
}

static expr_eval_t expression(bool skip_global_check) {
    return parse_next(skip_global_check);
}

static void synchronize() {
    if (parser.previous.line != parser.current.line) {
        parser.panic = false;
    }
}

static void add_main_call() {
    uint8_t main_procedure = make_constant(OBJ_VAL(copy_string("main", 4)));
    emit_bytes(OP_GET_GLOBAL, main_procedure);
    emit_bytes(OP_CALL, 0);
}

procedure_t *compile(const char *source, const char *path) {
    filename = path;
    compiler_t compiler;
    init_scanner(source);
    init_compiler(&compiler, TYPE_PROGRAM);

    parser.erred = false;
    parser.panic = false;

    advance();
    while (!match(TOKEN_EOF)) {
        expression(false);
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

void mark_compiler_roots() {
    compiler_t *compiler = current;
    while (compiler != NULL) {
        mark_object((obj_t *)compiler->procedure);
        compiler = compiler->enclosing;
    }
}
