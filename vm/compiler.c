#include <stdio.h>
#include <stdlib.h>

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
  PREC_EXPRESSION,  // expression literals
  PREC_OR,          // or
  PREC_AND,         // and
  PREC_EQUALITY,    // =
  PREC_COMPARISON,  // < >
  PREC_TERM,        // + -
  PREC_FACTOR,      // * /
  PREC_UNARY,       // ! -
  PREC_CALL,        // . ()
  PREC_PRIMARY
} precedence_t;

typedef void (*parse_fn)();

typedef struct {
    parse_fn prefix;
    parse_fn infix;
    precedence_t precedence;
} parse_rule_t;

parser_t parser;
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

static void end_compiler() {
    emit_return();

#ifdef DEBUG_PRINT_CODE
    if (!parser.erred) {
        disassemble_chunk(current_chunk(), "code");
    }
#endif
}

static void expression();
static parse_rule_t *get_rule(token_type_t type);
static void parse_precedence(precedence_t precedence);

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

static void unary() {
    token_type_t operator_type = parser.previous.type;
    parse_precedence(PREC_UNARY);

    switch (operator_type) {
        case TOKEN_BANG: emit_byte(OP_NOT);     break;
        case TOKEN_MINUS: emit_byte(OP_NEGATE); break;
        default: return;
    }
}

parse_rule_t rules[] = {
    [TOKEN_LEFT_PAREN]    = {grouping,    NULL,       PREC_NONE},
    [TOKEN_RIGHT_PAREN]   = {NULL,        NULL,       PREC_NONE},
    [TOKEN_LEFT_BRACKET]  = {NULL,        NULL,       PREC_NONE},
    [TOKEN_RIGHT_BRACKET] = {NULL,        NULL,       PREC_NONE},
    [TOKEN_COMMA]         = {NULL,        NULL,       PREC_NONE},
    [TOKEN_DOT]           = {NULL,        NULL,       PREC_NONE},
    [TOKEN_COLON]         = {NULL,        NULL,       PREC_NONE},
    [TOKEN_COLON_COLON]   = {NULL,        NULL,       PREC_NONE},
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
    [TOKEN_SYMBOL]        = {NULL,        NULL,       PREC_NONE},
    [TOKEN_STRING]        = {string,      string,     PREC_EXPRESSION},
    [TOKEN_NUMBER]        = {number,      number,     PREC_EXPRESSION},
    [TOKEN_AND]           = {NULL,        NULL,       PREC_NONE},
    [TOKEN_FALSE]         = {literal,     literal,    PREC_EXPRESSION},
    [TOKEN_FOR]           = {NULL,        NULL,       PREC_NONE},
    [TOKEN_IF]            = {NULL,        NULL,       PREC_NONE},
    [TOKEN_NIL]           = {literal,     literal,    PREC_EXPRESSION},
    [TOKEN_OR]            = {NULL,        NULL,       PREC_NONE},
    [TOKEN_PRINT]         = {NULL,        NULL,       PREC_NONE},
    [TOKEN_TRUE]          = {literal,     literal,    PREC_EXPRESSION},
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
        parse_fn infix_rule = get_rule(parser.previous.type)->infix;
        infix_rule();
    }
}

static parse_rule_t *get_rule(token_type_t type) {
    return &rules[type];
}

static void expression() {
    parse_precedence(PREC_EXPRESSION);
}

bool compile(const char *source, chunk_t *chunk) {
    init_scanner(source);
    compiling_chunk = chunk;

    parser.erred = false;
    parser.panic = false;

    advance();
    expression();
    consume(TOKEN_EOF, "expect end of expression.");
    end_compiler();
    return !parser.erred;
}
