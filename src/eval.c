#include "eval.h"
#include "nexp.h"
#include "builtin.h"
#include "scope.h"

static nexp_t *eval_Sexpr(scope_t *scope, nexp_t *nexp) {
    // Evaluate all children
    for (u32 i = 0; i < nexp->count; i++)
        nexp->children[i] = eval_nexp(scope, nexp->children[i]);

    // Report found errors.
    // TODO: This is not a good implementation because it reports the first error found.
    // It can be frustrating if the user gets more than 1 error and it has fix one-by-one instead
    // of fixing the batch. Fix this so it can report all errors at once.
    for (u32 i = 0; i < nexp->count; i++)
        if (nexp->children[i]->type == NEXP_TYPE_ERROR) return nexp_take(nexp, i);

    if (nexp->count == 0) return nexp;
    if (nexp->count == 1) return nexp_take(nexp, 0);

    // Make sure the first element is always a symbol
    nexp_t *found = nexp_pop(nexp, 0);
    if (found->type != NEXP_TYPE_PROC) {
        nexp_delete(nexp);
        nexp_delete(found);
        return nexp_new_error("expression is not a procedure");
    }

    nexp_t *result = found->proc(scope, nexp);
    nexp_delete(found);
    return result;
}

nexp_t *eval_nexp(scope_t *scope, nexp_t *nexp) {
    // Act on symbols (if they exists in scope) and S-expressions.
    if (nexp->type == NEXP_TYPE_SYMBOL) {
        nexp_t *found = scope_get(scope, nexp);
        nexp_delete(nexp);
        return found;
    }

    if (nexp->type == NEXP_TYPE_SEXPR) return eval_Sexpr(scope, nexp);

    return nexp;
}
