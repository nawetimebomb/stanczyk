/* The Stańczyk Programming Language
 *
 *            ¿«fº"└└-.`└└*∞▄_              ╓▄∞╙╙└└└╙╙*▄▄
 *         J^. ,▄▄▄▄▄▄_      └▀████▄ç    JA▀            └▀v
 *       ,┘ ▄████████████▄¿     ▀██████▄▀└      ╓▄██████▄¿ "▄_
 *      ,─╓██▀└└└╙▀█████████      ▀████╘      ▄████████████_`██▄
 *     ;"▄█└      ,██████████-     ▐█▀      ▄███████▀▀J█████▄▐▀██▄
 *     ▌█▀      _▄█▀▀█████████      █      ▄██████▌▄▀╙     ▀█▐▄,▀██▄
 *    ▐▄▀     A└-▀▌  █████████      ║     J███████▀         ▐▌▌╙█µ▀█▄
 *  A╙└▀█∩   [    █  █████████      ▌     ███████H          J██ç ▀▄╙█_
 * █    ▐▌    ▀▄▄▀  J█████████      H    ████████          █    █  ▀▄▌
 *  ▀▄▄█▀.          █████████▌           ████████          █ç__▄▀ ╓▀└ ╙%_
 *                 ▐█████████      ▐    J████████▌          .└╙   █¿   ,▌
 *                 █████████▀╙╙█▌└▐█╙└██▀▀████████                 ╙▀▀▀▀
 *                ▐██▀┘Å▀▄A └▓█╓▐█▄▄██▄J▀@└▐▄Å▌▀██▌
 *                █▄▌▄█M╨╙└└-           .└└▀**▀█▄,▌
 *                ²▀█▄▄L_                  _J▄▄▄█▀└
 *                     └╙▀▀▀▀▀MMMR████▀▀▀▀▀▀▀└
 *
 *
 * ███████╗████████╗ █████╗ ███╗   ██╗ ██████╗███████╗██╗   ██╗██╗  ██╗
 * ██╔════╝╚══██╔══╝██╔══██╗████╗  ██║██╔════╝╚══███╔╝╚██╗ ██╔╝██║ ██╔╝
 * ███████╗   ██║   ███████║██╔██╗ ██║██║       ███╔╝  ╚████╔╝ █████╔╝
 * ╚════██║   ██║   ██╔══██║██║╚██╗██║██║      ███╔╝    ╚██╔╝  ██╔═██╗
 * ███████║   ██║   ██║  ██║██║ ╚████║╚██████╗███████╗   ██║   ██║  ██╗
 * ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝
 */
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "scanner.h"
#include "util.h"

typedef struct {
    const char *filename;
    const char *start;
    const char *current;
    const char *column;
    int line;
} Scanner;

Scanner scanner;

void init_scanner(const char *filename, const char *source) {
    scanner.filename = filename;
    scanner.start = source;
    scanner.current = source;
    scanner.column = source;
    scanner.line = 1;
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

static Token make_token(TokenType type) {
    Token token;
    token.type = type;
    token.start = scanner.start;
    token.length = (int)(scanner.current - scanner.start);
    token.line = scanner.line;
    token.column = scanner.start - scanner.column;
    token.filename = scanner.filename;
    return token;
}

static Token error_token(const char *message) {
    Token token;
    token.type = TOKEN_ERROR;
    token.start = message;
    token.length = (int)strlen(message);
    token.line = scanner.line;
    token.column = scanner.start - scanner.column;
    token.filename = scanner.filename;
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
                scanner.column = scanner.current + 1;
                advance();
                break;
            default: return;
        }
    }
}

static bool check_if_keyword(int start, int length, const char *rest) {
    return (scanner.current - scanner.start == start + length &&
            memcmp(scanner.start + start, rest, length) == 0);
}

static TokenType check_keyword(int start, int length, const char *rest, TokenType type) {
    if (scanner.current - scanner.start == start + length &&
        memcmp(scanner.start + start, rest, length) == 0) {
        return type;
    }

    return TOKEN_WORD;
}

static TokenType keyword_type() {
    switch (scanner.start[0]) {
        case '_': {
            if (check_if_keyword(1, 9, "_SYSCALL0"))   return TOKEN___SYSCALL0;
            if (check_if_keyword(1, 9, "_SYSCALL1"))   return TOKEN___SYSCALL1;
            if (check_if_keyword(1, 9, "_SYSCALL2"))   return TOKEN___SYSCALL2;
            if (check_if_keyword(1, 9, "_SYSCALL3"))   return TOKEN___SYSCALL3;
            if (check_if_keyword(1, 9, "_SYSCALL4"))   return TOKEN___SYSCALL4;
            if (check_if_keyword(1, 9, "_SYSCALL5"))   return TOKEN___SYSCALL5;
            if (check_if_keyword(1, 9, "_SYSCALL6"))   return TOKEN___SYSCALL6;
        } break;
        case 'b': return check_keyword(1, 3, "ool", TOKEN_DTYPE_BOOL);
        case 'd': {
            if (scanner.current - scanner.start > 1) {
                switch (scanner.start[1]) {
                    case 'o': return check_keyword(2, 0, "", TOKEN_DO);
                    case 'r': return check_keyword(2, 2, "op", TOKEN_DROP);
                }
            }
        } break;
        case 'f': return check_keyword(1, 4, "alse", TOKEN_FALSE);
        case 'i': return check_keyword(1, 2, "nt", TOKEN_DTYPE_INT);
        case 'm': return check_keyword(1, 4, "acro", TOKEN_MACRO);
        case 'p': {
            if (scanner.current - scanner.start > 1) {
                switch (scanner.start[1]) {
                    case 'r': return check_keyword(2, 3, "int", TOKEN_PRINT);
                    case 't': return check_keyword(2, 1, "r", TOKEN_DTYPE_PTR);
                }
            }
        } break;
        case 't': return check_keyword(1, 3, "rue", TOKEN_TRUE);
        case 'u': return check_keyword(1, 4, "sing", TOKEN_USING);
    }

    return TOKEN_WORD;
}

static Token keyword() {
    while (is_alpha(peek()) || is_digit(peek()) || is_allowed_char(peek())) advance();

    return make_token(keyword_type());
}

static Token number() {
    TokenType type = TOKEN_INT;
    while (is_digit(peek())) advance();

    // if (peek() == '.' && is_digit(peek_next())) {
    //     type = TOKEN_FLOAT;
    //     advance();
    //     while (is_digit(peek())) advance();
    // }

    // if (peek() == 'x' && (is_digit(peek_next()) || is_alpha(peek_next()))) {
    //     type = TOKEN_HEX;
    //     advance();
    //     while (is_digit(peek()) || is_alpha(peek())) advance();
    // }

    return make_token(type);
}

static Token string() {
    while (peek() != '"' && !is_at_eof()) {
        advance();
    }
    if (is_at_eof()) return error_token("unterminated string");
    advance();
    return make_token(TOKEN_STR);
}

Token scan_token() {
    skip_whitespace();
    scanner.start = scanner.current;

    if (is_at_eof()) return make_token(TOKEN_EOF);

    char c = advance();
    if (is_digit(c)) return number();

    switch (c) {
        case '(': return make_token(TOKEN_LEFT_PAREN);
        case ')': return make_token(TOKEN_RIGHT_PAREN);
        case '.': return make_token(TOKEN_DOT);
        case '+': return make_token(TOKEN_PLUS);
        case '-': return make_token(TOKEN_MINUS);
        case '*': return make_token(TOKEN_STAR);
        case '/': return make_token(TOKEN_SLASH);
        case '%': return make_token(TOKEN_PERCENT);
        case '=': return make_token(TOKEN_EQUAL);
        case '!': {
            if (match('=')) {
                return make_token(TOKEN_BANG_EQUAL);
            }
        } break;
        case '<': return make_token(match('=') ? TOKEN_LESS_EQUAL : TOKEN_LESS);
        case '>': return make_token(match('=') ? TOKEN_GREATER_EQUAL : TOKEN_GREATER);
        case '"': return string();
        default: return keyword();
    }

    return error_token("unknown token");
}
