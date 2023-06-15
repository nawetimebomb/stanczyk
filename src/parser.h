#ifndef NLISP_PARSER_H
#define NLISP_PARSER_H

#include "includes/mpc.h"
#include "nexp.h"

typedef enum {
    NEXP_PARSER_TYPE_NUMBER,
    NEXP_PARSER_TYPE_SYMBOL,
    NEXP_PARSER_TYPE_STRING,
    NEXP_PARSER_TYPE_COMMENT,
    NEXP_PARSER_TYPE_SEXPR,
    NEXP_PARSER_TYPE_BEXPR,
    NEXP_PARSER_TYPE_EXPR
} parser_type_t;

void init_parser();
mpc_parser_t *get_parser_type(parser_type_t);
nexp_t *parse_expr(mpc_ast_t *ast);

#endif
