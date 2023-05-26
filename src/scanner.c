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
#include <string.h>

#include "scanner.h"

typedef struct {
    const char *start;
    const char *current;
    const char *column;
    int line;
} Scanner;

Scanner scanner;

void init_scanner(const char *source) {
    scanner.start = source;
    scanner.current = source;
    scanner.column = source;
    scanner.line = 1;
}

static bool is_digit(char c) {
    return c >= '0' && c <= '9';
}

static bool is_alpha(char c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
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

static TokenType check_keyword(int start, int length, const char *rest, TokenType type) {
    if (scanner.current - scanner.start == start + length &&
        memcmp(scanner.start + start, rest, length) == 0) {
        return type;
    }

    return TOKEN_UNKNOWN;
}

static TokenType keyword_type() {
    switch (scanner.start[0]) {
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
        }
        case 'e': return check_keyword(1, 3, "lse", TOKEN_ELSE);
        case 'i': {
            if (scanner.current - scanner.start > 1) {
                if (scanner.start[1] == 'f') return TOKEN_IF;
                switch (scanner.start[1]) {
                    case 'n': return check_keyword(2, 1, "c", TOKEN_INC);
                }
            }
        }
        case 'l': return check_keyword(1, 3, "oop", TOKEN_LOOP);
        case 'm': return check_keyword(1, 5, "emory", TOKEN_MEMORY);
        case 'o': {
            if (scanner.current - scanner.start > 1) {
                if (scanner.start[1] == 'r') return TOKEN_OR;
                switch (scanner.start[1]) {
                    case 'v': return check_keyword(2, 2, "er", TOKEN_OVER);
                }
            }
        }
        case 'p': return check_keyword(1, 4, "rint", TOKEN_PRINT);
        case 's': {
            if (scanner.current - scanner.start > 1) {
                switch (scanner.start[1]) {
                    case 'w': return check_keyword(2, 2, "ap", TOKEN_SWAP);
                    case 'y': return check_keyword(2, 2, "s4", TOKEN_SYS4);
                }
            }
        }
    }

    return TOKEN_UNKNOWN;
}

static Token keyword() {
    while (is_alpha(peek()) || is_digit(peek())) advance();

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
    if (is_alpha(c)) return keyword();

    switch (c) {
        case '.': return make_token(TOKEN_DOT);
        case '-': return make_token(TOKEN_MINUS);
        case '+': return make_token(TOKEN_PLUS);
        case '/': return make_token(TOKEN_SLASH);
        case '*': return make_token(TOKEN_STAR);
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
        case '"': return string();
    }

    return error_token("unknown token found");
}
