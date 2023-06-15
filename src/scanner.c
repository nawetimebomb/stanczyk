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
        case '#': {
            if (scanner.current - scanner.start > 1) {
                switch (scanner.start[1]) {
                    case 'i': return check_keyword(2, 6, "nclude", TOKEN_HASH_INCLUDE);
                }
            }
        } break;
        case '_': {
            if (check_if_keyword(1, 8,  "_SYS_ADD"))     return TOKEN___SYS_ADD;
            if (check_if_keyword(1, 8,  "_SYS_SUB"))     return TOKEN___SYS_SUB;
            if (check_if_keyword(1, 8,  "_SYS_MUL"))     return TOKEN___SYS_MUL;
            if (check_if_keyword(1, 11, "_SYS_DIVMOD"))  return TOKEN___SYS_DIVMOD;
            if (check_if_keyword(1, 10, "_SYS_CALL0"))   return TOKEN___SYS_CALL0;
            if (check_if_keyword(1, 10, "_SYS_CALL1"))   return TOKEN___SYS_CALL1;
            if (check_if_keyword(1, 10, "_SYS_CALL2"))   return TOKEN___SYS_CALL2;
            if (check_if_keyword(1, 10, "_SYS_CALL3"))   return TOKEN___SYS_CALL3;
            if (check_if_keyword(1, 10, "_SYS_CALL4"))   return TOKEN___SYS_CALL4;
            if (check_if_keyword(1, 10, "_SYS_CALL5"))   return TOKEN___SYS_CALL5;
            if (check_if_keyword(1, 10, "_SYS_CALL6"))   return TOKEN___SYS_CALL6;
        } break;
        case 'a': return check_keyword(1, 2, "nd", TOKEN_AND);
        case 'd': {
            if (scanner.current - scanner.start > 1) {
                if (scanner.start[1] == 'o') return TOKEN_DO;
                switch (scanner.start[1]) {
                    case 'e': return check_keyword(2, 1, "c", TOKEN_DEC);
                    case 'r': return check_keyword(2, 2, "op", TOKEN_DROP);
                    case 'u': return check_keyword(2, 1, "p", TOKEN_DUP);
                }
            }
        } break;
        case 'e': {
            if (scanner.current - scanner.start > 1) {
                switch (scanner.start[1]) {
                    case 'l': return check_keyword(2, 2, "se", TOKEN_ELSE);
                    case 'n': return check_keyword(2, 1, "d", TOKEN_END);
                }
            }
        } break;
        case 'i': {
            if (scanner.current - scanner.start > 1) {
                if (scanner.start[1] == 'f') return TOKEN_IF;
                switch (scanner.start[1]) {
                    case 'n': return check_keyword(2, 1, "c", TOKEN_INC);
                }
            }
        } break;
        case 'l': return check_keyword(1, 3, "oop", TOKEN_LOOP);
        case 'm': return check_keyword(1, 5, "emory", TOKEN_MEMORY);
        case 'o': {
            if (scanner.current - scanner.start > 1) {
                if (scanner.start[1] == 'r') return TOKEN_OR;
                switch (scanner.start[1]) {
                    case 'v': return check_keyword(2, 2, "er", TOKEN_OVER);
                }
            }
        } break;
        case 'p': return check_keyword(1, 4, "rint", TOKEN_PRINT);
        case 's': {
            if (scanner.current - scanner.start > 1) {
                switch (scanner.start[1]) {
                    case 'e': return check_keyword(2, 1, "t", TOKEN_SET);
                    case 'w': return check_keyword(2, 2, "ap", TOKEN_SWAP);
                }
            }
        } break;
    }

    return TOKEN_WORD;
}

static Token keyword() {
    while (is_alpha(peek()) || is_digit(peek()) || is_allowed_char(peek())) advance();

    return make_token(keyword_type());
}

static Token number() {
    while (is_digit(peek())) advance();
    return make_token(TOKEN_INT);
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
        case '.': return make_token(TOKEN_DOT);
        case '!': {
            if (match('=')) return make_token(TOKEN_NOT_EQUAL);
            if (match('8')) return make_token(TOKEN_SAVE8);
            return error_token("unknown token at '!'");
        }
        case '@': {
            if (match('8')) return make_token(TOKEN_LOAD8);
            return error_token("unknown token at '@'");
        }
        case '=': {
            if (match('=')) return make_token(TOKEN_EQUAL);
            return error_token("unknown token at '='");
        }
        case '<': return make_token(match('=') ? TOKEN_LESS_EQUAL : TOKEN_LESS);
        case '>': return make_token(match('=') ? TOKEN_GREATER_EQUAL : TOKEN_GREATER);
        case ':': {
            if (match(':')) return make_token(TOKEN_PROC);
            if (match('>')) return make_token(TOKEN_MACRO);
            if (match('=')) return make_token(TOKEN_CONST);
        } break;
        case '"': return string();
        default: return keyword();
    }

    return error_token("unknown token");
}
