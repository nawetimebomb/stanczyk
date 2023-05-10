#ifndef NLISP_PARSER_H
#define NLISP_PARSER_H

#include "includes/mpc.h"
#include "nexp.h"

nexp_t *read_expr(mpc_ast_t *ast);

#endif
