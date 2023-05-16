#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "chunk.h"
#include "common.h"
#include "compiler.h"
#include "debug.h"
#include "scanner.h"

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
  PREC_DECLARATION, // declaration
  PREC_EXPRESSION,  // expression literals
  PREC_OR,          // or
  PREC_AND,         // and
  PREC_EQUALITY,    // =
  PREC_COMPARISON,  // < >
  PREC_TERM,        // + -
  PREC_FACTOR,      // * /
  PREC_UNARY,       // ! -
  PREC_CALL,        // . ()
  PREC_END,         // ret
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

typedef struct {
    local_t locals[UINT8_COUNT];
    int local_count;
    int scope_depth;
} compiler_t;

parser_t parser;
compiler_t *current = NULL;
chunk_t *compiling_chunk;

static chunk_t *current_chunk() {
    return compiling_chunk;
}

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

static void error(const char *message) {
    error_at(&parser.previous, message);
}

static void error_at_current(const char *message) {
    error_at(&parser.current, message);
}

static void advance() {
    parser.previous = parser.current;

    for (;;) {
        parser.current = scan_token();
        if (parser.current.type != TOKEN_ERROR) break;

        error_at_current(parser.current.start);
    }
}

static void consume(token_type_t type, const char *message) {
    if (parser.current.type == type) {
        advance();
        return;
    }

    error_at_current(message);
}

static bool check(token_type_t type) {
    return parser.current.type == type;
}

static bool match(token_type_t type) {
    if (!check(type)) return false;
    advance();
    return true;
}

static void emit_byte(uint8_t byte) {
    write_chunk(current_chunk(), byte, parser.previous.line);
}

static void emit_bytes(uint8_t b1, uint8_t b2) {
    emit_byte(b1);
    emit_byte(b2);
}

static void emit_return() {
    emit_byte(OP_RETURN);
}

static uint8_t make_constant(value_t value) {
    int constant = add_constant(current_chunk(), value);
    if (constant > UINT8_MAX) {
        error("too many constants in one chunk.");
        return 0;
    }

    return (uint8_t)constant;
}

static void emit_constant(value_t value) {
    emit_bytes(OP_CONSTANT, make_constant(value));
}

static uint8_t symbol_constant(token_t *name) {
    return make_constant(OBJ_VAL(copy_string(name->start, name->length)));
}

static bool symbols_are_equal(token_t *a, token_t *b) {
    if (a->length != b->length) return false;
    return memcmp(a->start, b->start, a->length) == 0;
}

static int resolve_local(compiler_t *compiler, token_t *name) {
    for (int i = compiler->local_count - 1; i >= 0; i--) {
        local_t *local = &compiler->locals[i];
        if (symbols_are_equal(name, &local->name)) {
            return i;
        }
    }
    return -1;
}

static void add_local(token_t name) {
    if (current->local_count == UINT8_COUNT) {
        error("stack overflow. Too many local symbols declared in function.");
        return;
    }

    local_t *local = &current->locals[current->local_count++];
    local->name = name;
    local->depth = current->scope_depth;
}

static void declare_symbol() {
    // If it's a global, we go for the global route, so we skip from here.
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

static void define_symbol(uint8_t global) {
    //  We exit from here if the symbol is local
    if (current->scope_depth > 0) return;

    emit_bytes(OP_DEFINE_GLOBAL, global);
}

static uint8_t parse_symbol(const char *error_message) {
    consume(TOKEN_SYMBOL, error_message);

    declare_symbol();
    // If it's in a block, we escape from here, symbol was already declared above.
    if (current->scope_depth > 0) return 0;

    // If not, we go global.
    return symbol_constant(&parser.previous);
}

static void init_compiler(compiler_t *compiler) {
    compiler->local_count = 0;
    compiler->scope_depth = 0;
    current = compiler;
}

static void end_compiler() {
    emit_return();

#ifdef DEBUG_PRINT_CODE
    if (!parser.erred) {
        disassemble_chunk(current_chunk(), "code");
    }
#endif
}

static void begin_scope() {
    current->scope_depth++;
}

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

static void expression();
static parse_rule_t *get_rule(token_type_t type);
static void parse_precedence(precedence_t precedence);

static void block() {
    while(!check(TOKEN_DOT) && !check(TOKEN_EOF)) {
        expression();
    }

    consume(TOKEN_DOT, "expect '.' to end block");
}

static void binary() {
    token_type_t operator_type = parser.previous.type;

    switch (operator_type) {
        case TOKEN_BANG_EQUAL:
            emit_bytes(OP_EQUAL, OP_NOT); break;
        case TOKEN_EQUAL_EQUAL:
            emit_byte(OP_EQUAL); break;
        case TOKEN_GREATER:
            emit_byte(OP_GREATER); break;
        case TOKEN_GREATER_EQUAL:
            emit_bytes(OP_LESS, OP_NOT); break;
        case TOKEN_LESS:
            emit_byte(OP_LESS); break;
        case TOKEN_LESS_EQUAL:
            emit_bytes(OP_GREATER, OP_NOT); break;
        case TOKEN_PLUS:
            emit_byte(OP_ADD); break;
        case TOKEN_MINUS:
            emit_byte(OP_SUBTRACT); break;
        case TOKEN_STAR:
            emit_byte(OP_MULTIPLY); break;
        case TOKEN_SLASH:
            emit_byte(OP_DIVIDE); break;
        default: return;
    }
}

static void literal() {
    switch (parser.previous.type) {
        case TOKEN_FALSE: emit_byte(OP_FALSE); break;
        case TOKEN_NIL:   emit_byte(OP_NIL); break;
        case TOKEN_TRUE:  emit_byte(OP_TRUE); break;
        default: return;
    }
}

static void grouping() {
    expression();
    consume(TOKEN_RIGHT_PAREN, "Expect ')' after expression.");
}

static void number() {
    double value = strtod(parser.previous.start, NULL);
    emit_constant(NUMBER_VAL(value));
}

static void string() {
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

static void symbol() {
    named_symbol(parser.previous, false);
}

static void unary() {
    token_type_t operator_type = parser.previous.type;
    parse_precedence(PREC_UNARY);

    switch (operator_type) {
        case TOKEN_BANG: emit_byte(OP_NOT);     break;
        case TOKEN_MINUS: emit_byte(OP_NEGATE); break;
        default: return;
    }
}

static void statement()  {
    token_type_t statement_type = parser.previous.type;

    switch (statement_type) {
        case TOKEN_PRINT: emit_byte(OP_PRINT); break;
        case TOKEN_DROP:  emit_byte(OP_DROP);  break;
        case TOKEN_DO: {
            begin_scope();
            block();
            end_scope();
        } break;
        default: return;
    }
}

static void declaration() {
    uint8_t symbol;

    // TODO: Add static type declaration
    // := does type inference
    if (match(TOKEN_EQUAL)) {
        symbol = parse_symbol("expect symbol name after \":=\"");
    } else {
        error("failed to declare symbol due to missing \"=\"");
    }

    if (match(TOKEN_DOT)) {
        emit_byte(OP_NIL);
    } else {
        while(!check(TOKEN_DOT) && !check(TOKEN_EOF)) {
            expression();
        }
        consume(TOKEN_DOT, "expect '.' after symbol declaration.");
    }

    define_symbol(symbol);
}

// TODO: This function has a bug because it's treating all assignment as local
// assignment when I'm on a block.
// Inside a block, a statement like = my-global-var 13 . should treat that value
// as global, not local
static void assignment() {
    consume(TOKEN_SYMBOL, "expect symbol name after \"=\"");
    token_t name = parser.previous;

    if (match(TOKEN_DOT)) {
        emit_byte(OP_NIL);
    } else {
        while(!check(TOKEN_DOT) && !check(TOKEN_EOF)) {
            expression();
        }
        consume(TOKEN_DOT, "expect '.' after symbol assignment.");
    }

    named_symbol(name, true);
}

parse_rule_t rules[] = {
    [TOKEN_LEFT_PAREN]    = {grouping,    NULL,       PREC_NONE},
    [TOKEN_RIGHT_PAREN]   = {NULL,        NULL,       PREC_NONE},
    [TOKEN_LEFT_BRACKET]  = {NULL,        NULL,       PREC_NONE},
    [TOKEN_RIGHT_BRACKET] = {NULL,        NULL,       PREC_NONE},
    [TOKEN_COMMA]         = {NULL,        NULL,       PREC_NONE},
    [TOKEN_EQUAL]         = {assignment,  NULL,       PREC_DECLARATION},
    [TOKEN_COLON]         = {declaration, NULL,       PREC_DECLARATION},
    [TOKEN_MINUS]         = {unary,       binary,     PREC_TERM},
    [TOKEN_PLUS]          = {NULL,        binary,     PREC_TERM},
    [TOKEN_SLASH]         = {NULL,        binary,     PREC_FACTOR},
    [TOKEN_STAR]          = {NULL,        binary,     PREC_FACTOR},
    [TOKEN_BANG]          = {unary,       unary,      PREC_UNARY},
    [TOKEN_BANG_EQUAL]    = {NULL,        binary,     PREC_EQUALITY},
    [TOKEN_EQUAL_EQUAL]   = {NULL,        binary,     PREC_EQUALITY},
    [TOKEN_GREATER]       = {NULL,        binary,     PREC_EQUALITY},
    [TOKEN_GREATER_EQUAL] = {NULL,        binary,     PREC_EQUALITY},
    [TOKEN_LESS]          = {NULL,        binary,     PREC_EQUALITY},
    [TOKEN_LESS_EQUAL]    = {NULL,        binary,     PREC_EQUALITY},
    [TOKEN_SYMBOL]        = {symbol,      symbol,     PREC_EXPRESSION},
    [TOKEN_STRING]        = {string,      string,     PREC_EXPRESSION},
    [TOKEN_NUMBER]        = {number,      number,     PREC_EXPRESSION},
    [TOKEN_AND]           = {NULL,        NULL,       PREC_NONE},
    [TOKEN_FALSE]         = {literal,     literal,    PREC_EXPRESSION},
    [TOKEN_TRUE]          = {literal,     literal,    PREC_EXPRESSION},
    [TOKEN_NIL]           = {literal,     literal,    PREC_EXPRESSION},
    [TOKEN_FOR]           = {NULL,        NULL,       PREC_NONE},
    [TOKEN_IF]            = {NULL,        NULL,       PREC_NONE},
    [TOKEN_OR]            = {NULL,        NULL,       PREC_NONE},
    [TOKEN_PRINT]         = {statement,   NULL,       PREC_NONE},
    [TOKEN_DROP]          = {statement,   NULL,       PREC_NONE},
    [TOKEN_DO]            = {statement,   NULL,       PREC_NONE},
    [TOKEN_DUP]           = {NULL,        NULL,       PREC_NONE},
    [TOKEN_DOT]           = {NULL,        NULL,       PREC_NONE},
    [TOKEN_ERROR]         = {NULL,        NULL,       PREC_NONE},
    [TOKEN_EOF]           = {NULL,        NULL,       PREC_NONE}
};

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

bool compile(const char *source, chunk_t *chunk) {
    compiler_t compiler;
    init_scanner(source);
    init_compiler(&compiler);
    compiling_chunk = chunk;

    parser.erred = false;
    parser.panic = false;

    advance();
    while (!match(TOKEN_EOF)) {
        expression();
        if (parser.panic) synchronize();
    }

    end_compiler();
    return !parser.erred;
}