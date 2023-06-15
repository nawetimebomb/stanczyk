#include <errno.h>
#include "parser.h"
#include "nexp.h"
#include "types.h"

static nexp_t *read_number(mpc_ast_t *ast) {
    errno = 0;
    i64 result = strtol(ast->contents, NULL, 10);
    return errno != ERANGE ?
        nexp_new_number(result) :
        nexp_new_error("Invalid number");
}

static nexp_t *add_child_sexpr(nexp_t *parent, nexp_t *child) {
    parent->count++;
    parent->children = realloc(parent->children, sizeof(nexp_t*) * parent->count);
    parent->children[parent->count - 1] = child;
    return parent;
}

nexp_t *read_expr(mpc_ast_t *ast) {
    if (strstr(ast->tag, "number")) return read_number(ast);
    if (strstr(ast->tag, "symbol")) return nexp_new_symbol(ast->contents);

    nexp_t *result;
    if (strcmp(ast->tag, ">") == 0) result = nexp_new_sexpr();
    if (strstr(ast->tag, "sexpr")) result = nexp_new_sexpr();

    // Valid expressions that we can skip
    for (u32 i = 0; i < ast->children_num; i++) {
        if (strcmp(ast->children[i]->contents, "(") == 0) continue;
        if (strcmp(ast->children[i]->contents, ")") == 0) continue;
        if (strcmp(ast->children[i]->tag, "regex") == 0) continue;
        result = add_child_sexpr(result, read_expr(ast->children[i]));
    }

    return result;
}
