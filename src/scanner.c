#include <stdio.h>
#include <string.h>

#include "common.h"
#include "scanner.h"

typedef struct {
    const char *start;
    const char *current;
    int line;
} scanner_t;

scanner_t scanner;

void init_scanner(const char *source) {
    scanner.start = source;
    scanner.current = source;
    scanner.line = 1;
}

static bool is_digit(char c) {
    return c >= '0' && c <= '9';
}

static bool is_alpha(char c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

static bool is_allowed_char(char c) {
    return (c == '-');
}

static bool is_at_eof() {
    return *scanner.current == '\0';
}

static char advance() {
    scanner.current++;
    return scanner.current[-1];
}

static bool match(char expected) {
    if (is_at_eof()) return false;
    if (*scanner.current != expected) return false;
    scanner.current++;
    return true;
}

static char peek() {
    return *scanner.current;
}

static char peek_next() {
    if (is_at_eof()) return '\0';
    return scanner.current[1];
}

static token_t make_token(token_type_t type) {
    token_t token;
    token.type = type;
    token.start = scanner.start;
    token.length = (int)(scanner.current - scanner.start);
    token.line = scanner.line;
    return token;
}

static token_t error_token(const char *message) {
    token_t token;
    token.type = TOKEN_ERROR;
    token.start = message;
    token.length = (int)strlen(message);
    token.line = scanner.line;
    return token;
}

static void skip_whitespace() {
    for (;;) {
        char c = peek();
        switch (c) {
            case ' ':
            case '\r':
            case '\t':
                advance(); break;
            case '\n':
                scanner.line++;
                advance();
                break;
            case ';':
                while (peek() != '\n' && !is_at_eof()) advance();
                break;
            default: return;
        }
    }
}

static token_type_t check_keyword(int start, int length, const char *rest, token_type_t type) {
    if (scanner.current - scanner.start == start + length &&
        memcmp(scanner.start + start, rest, length) == 0) {
        return type;
    }

    return TOKEN_SYMBOL;
}

static token_type_t symbol_type() {
    switch (scanner.start[0]) {
        case 'a': return check_keyword(1, 2, "nd", TOKEN_AND);
        case 'd': {
            if (scanner.current - scanner.start > 1) {
                if (scanner.start[1] == 'o') return TOKEN_DO;
                switch(scanner.start[1]) {
                    case 'r': return check_keyword(2, 2, "op", TOKEN_DROP);
                    case 'u': return check_keyword(2, 1, "p", TOKEN_DUP);
                }
            }
        }
        case 'e': return check_keyword(1, 3, "lse", TOKEN_ELSE);
        case 'f': return check_keyword(1, 4, "alse", TOKEN_FALSE);
        case 'i': return check_keyword(1, 1, "f", TOKEN_IF);
        case 'n': {
            if (scanner.current - scanner.start > 1) {
                switch(scanner.start[1]) {
                    case 'e': return check_keyword(2, 1, "g", TOKEN_NEG);
                    case 'i': return check_keyword(2, 1, "l", TOKEN_NIL);
                }
            }
        }
        case 'o': return check_keyword(1, 1, "r", TOKEN_OR);
        case 'p': return check_keyword(1, 4, "rint", TOKEN_PRINT);
        case 'q': return check_keyword(1, 3, "uit", TOKEN_QUIT);
        case 't': return check_keyword(1, 3, "rue", TOKEN_TRUE);
    }

    return TOKEN_SYMBOL;
}

static token_t symbol() {
    // TODO: Add special characters we want to allow in symbol's names
    while (is_alpha(peek()) || is_digit(peek()) || is_allowed_char(peek())) advance();

    return make_token(symbol_type());
}

static token_t number() {
    while (is_digit(peek())) advance();

    if (peek() == '.' && is_digit(peek_next())) {
        advance();
        while (is_digit(peek())) advance();
    }

    return make_token(TOKEN_NUMBER);
}

static token_t string() {
    while (peek() != '"' && !is_at_eof()) {
        if (peek() == '\n') scanner.line++;
        advance();
    }

    if (is_at_eof()) return error_token("unterminated string.");

    advance();
    return make_token(TOKEN_STRING);
}

token_t scan_token() {
    skip_whitespace();
    scanner.start = scanner.current;

    if (is_at_eof()) return make_token(TOKEN_EOF);

    char c = advance();
    if (is_alpha(c)) return symbol();
    if (is_digit(c)) return number();

    switch (c) {
        case '(': return make_token(TOKEN_LEFT_PAREN);
        case ')': return make_token(TOKEN_RIGHT_PAREN);
        case '{': return make_token(TOKEN_LEFT_BRACKET);
        case '}': return make_token(TOKEN_RIGHT_BRACKET);
        case ':': return make_token(TOKEN_COLON);
        case ',': return make_token(TOKEN_COMMA);
        case '.': return make_token(TOKEN_DOT);
        case '-': return make_token(TOKEN_MINUS);
        case '+': return make_token(TOKEN_PLUS);
        case '/': return make_token(TOKEN_SLASH);
        case '*': return make_token(TOKEN_STAR);
        case '!': return make_token(match('=') ? TOKEN_BANG_EQUAL : TOKEN_BANG);
        case '=': return make_token(match('=') ? TOKEN_EQUAL_EQUAL : TOKEN_EQUAL);
        case '<': return make_token(match('=') ? TOKEN_LESS_EQUAL : TOKEN_LESS);
        case '>': return make_token(match('=') ? TOKEN_GREATER_EQUAL : TOKEN_GREATER);
        case '"': return string();
    }

    return error_token("unexpected character.");
}
