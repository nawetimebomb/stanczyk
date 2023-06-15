#ifndef NLISP_SCANNER_H
#define NLISP_SCANNER_H

typedef enum {
    // Single char tokens
    TOKEN_LEFT_PAREN,    // (
    TOKEN_RIGHT_PAREN,   // )
    TOKEN_LEFT_BRACE,    // {
    TOKEN_RIGHT_BRACE,   // }
    TOKEN_LEFT_BRACKET,  // [
    TOKEN_RIGHT_BRACKET, // ]
    TOKEN_COMMA,
    TOKEN_DOT,
    TOKEN_MINUS,
    TOKEN_PLUS,
    TOKEN_SLASH,
    TOKEN_STAR,
    TOKEN_COLON,
    TOKEN_EQUAL,
    TOKEN_BANG,
    TOKEN_GREATER,
    TOKEN_LESS,

    // Double char tokens
    TOKEN_PLUS_PLUS,
    TOKEN_MINUS_MINUS,
    TOKEN_DOUBLE_BRACKETS,
    TOKEN_BANG_EQUAL,
    TOKEN_EQUAL_EQUAL,
    TOKEN_GREATER_EQUAL,
    TOKEN_LESS_EQUAL,
    TOKEN_RIGHT_ARROW,
    TOKEN_LESS_GREATER,
    TOKEN_GREATER_LESS,
    TOKEN_DOT_DOT,

    // Literals
    TOKEN_SYMBOL,
    TOKEN_VALUE_STRING,
    TOKEN_VALUE_FLOAT,
    TOKEN_VALUE_INT,

    // Keywords
    TOKEN_AND,
    TOKEN_DO,
    TOKEN_DROP,
    TOKEN_DUP,
    TOKEN_ELSE,
    TOKEN_FALSE,
    TOKEN_IF,
    TOKEN_NIL,
    TOKEN_OR,
    TOKEN_NEG,
    TOKEN_PRINT,
    TOKEN_QUIT,
    TOKEN_TRUE,

    // Special
    TOKEN_ERROR,
    TOKEN_EOF
} token_type_t;

typedef struct {
    token_type_t type;
    const char *start;
    int length;
    int line;
} token_t;

void init_scanner(const char *source);
token_t scan_token();

#endif
