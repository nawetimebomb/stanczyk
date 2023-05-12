#include <errno.h>
#include "includes/mpc.h"
#include "parser.h"
#include "nexp.h"
#include "types.h"

static nexp_t *parse_number(mpc_ast_t *ast) {
    errno = 0;
    i64 result = strtol(ast->contents, NULL, 10);
    return errno != ERANGE ?
        nexp_new_number(result) :
        nexp_new_error("Invalid number");
}

static nexp_t *parse_string(mpc_ast_t *ast) {
    // Unscaping string
    ast->contents[strlen(ast->contents) - 1] = '\0';
    char *unescaped = malloc(strlen(ast->contents + 1) + 1);
    strcpy(unescaped, ast->contents + 1);
    unescaped = mpcf_unescape(unescaped);
    nexp_t *string = nexp_new_string(unescaped);
    free(unescaped);
    return string;
}

nexp_t *parse_expr(mpc_ast_t *ast) {
    if (strstr(ast->tag, "number")) return parse_number(ast);
    if (strstr(ast->tag, "string")) return parse_string(ast);
    if (strstr(ast->tag, "symbol")) return nexp_new_symbol(ast->contents);

    nexp_t *result;
    if (strcmp(ast->tag, ">") == 0) result = nexp_new_Sexpr();
    if (strstr(ast->tag, "Sexpr")) result = nexp_new_Sexpr();
    if (strstr(ast->tag, "Bexpr")) result = nexp_new_Bexpr();

    // Valid expressions that we can skip
    for (u32 i = 0; i < ast->children_num; i++) {
        if (strcmp(ast->children[i]->contents, "(" ) == 0) continue;
        if (strcmp(ast->children[i]->contents, ")" ) == 0) continue;
        if (strcmp(ast->children[i]->contents, "{" ) == 0) continue;
        if (strcmp(ast->children[i]->contents, "}" ) == 0) continue;
        if (strcmp(ast->children[i]->tag, "regex"  ) == 0) continue;
        if (strcmp(ast->children[i]->tag, "comment") == 0) continue;
        result = nexp_add(result, parse_expr(ast->children[i]));
    }

    return result;
}
