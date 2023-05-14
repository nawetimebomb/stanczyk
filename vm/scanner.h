#ifndef NLISP_SCANNER_H
#define NLISP_SCANNER_H

typedef enum {
  // Single character tokens
  TOKEN_LEFT_PAREN,
  TOKEN_RIGHT_PAREN,
  TOKEN_LEFT_BRACKET,
  TOKEN_RIGHT_BRACKET,
  TOKEN_COMMA,
  TOKEN_DOT,
  TOKEN_MINUS,
  TOKEN_PLUS,
  TOKEN_COLON,
  TOKEN_COLON_COLON,
  TOKEN_SLASH,
  TOKEN_STAR,
  TOKEN_BANG,
  TOKEN_BANG_EQUAL,
  TOKEN_EQUAL_EQUAL,
  TOKEN_GREATER,
  TOKEN_GREATER_EQUAL,
  TOKEN_LESS,
  TOKEN_LESS_EQUAL,

  // Literals
  TOKEN_SYMBOL,
  TOKEN_STRING,
  TOKEN_NUMBER,

  // Keywords
  TOKEN_AND,
  TOKEN_FALSE,
  TOKEN_FOR,
  TOKEN_IF,
  TOKEN_NIL,
  TOKEN_OR,
  TOKEN_PRINT,
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
