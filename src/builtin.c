#include <string.h>
#include "builtin.h"
#include "eval.h"
#include "nexp.h"
#include "intrinsics.h"

// TODO: Add documentation

/* Usage: (list <arguments>)
 *   <arguments>: Any type.
 *   Description: Modifies the input arguments and transform it into a B-expression.
 *   Example: (list 1 2 3 4) -> {1 2 3 4}                                               */
static nexp_t *builtin_list(nexp_t *input) {
    nexp_t *output = input;
    output->type = NEXP_TYPE_BEXPR;
    return output;
}

/* Usage: (eval <argument>)
 *   <argument>: A B-expression with any type content.
 *   Description: Evaluates the content of a B-expression.
 *   Example: (eval { + 11 2 }) - > 13                                                  */
static nexp_t *builtin_eval(nexp_t *input) {
    NASSERT(input, input->count == 1,
            "(eval ...) can only have one argument");
    NASSERT(input, input->children[0]->type == NEXP_TYPE_BEXPR,
            "(eval ...) argument can only be a B-expression");

    nexp_t *result = nexp_take(input, 0);
    result->type = NEXP_TYPE_SEXPR;
    return eval_nexp(result);
}

static nexp_t *builtin_plus(nexp_t *input) {
    // Get the first child type, and match it with the other children.
    nexp_type_t eq_type = input->children[0]->type;

    for (u32 i = 0; i < input->count; i++) {
        // TODO: Add the ability to show which type I'm talking about by saving the
        // type on the nexp_t struct. [static types]
        if (input->children[i]->type != NEXP_TYPE_BEXPR &&
            input->children[i]->type != NEXP_TYPE_NUMBER) {
            nexp_delete(input);
            return nexp_new_error("(+ ...) unsupported type");
        }

        if (input->children[i]->type != eq_type) {
            nexp_delete(input);
            return nexp_new_error("(+ ...) can't mix and match types");
        }
    }

    nexp_t *result = nexp_pop(input, 0);

    switch (eq_type) {
        case NEXP_TYPE_NUMBER: {
            while (input->count > 0) {
                nexp_t *next = nexp_pop(input, 0);
                result->value += next->value;
            }
        } break;
        case NEXP_TYPE_BEXPR: {
            while (input->count)
                result = nexp_join(result, nexp_pop(input, 0));
        } break;
        // The rest of the types are skipped.
        default: break;
    }

    nexp_delete(input);
    return result;
}

static nexp_t *builtin_minus(nexp_t *input) {
    for (u32 i = 0; i < input->count; i++) {
        if (input->children[i]->type != NEXP_TYPE_NUMBER) {
            nexp_delete(input);
            return nexp_new_error("(- ...) unsupported type");
        }
    }

    nexp_t *result = nexp_pop(input, 0);

    while (input->count)  {
        nexp_t *next = nexp_pop(input, 0);
        result->value -= next->value;
    }

    nexp_delete(input);
    return result;
}

static nexp_t *builtin_star(nexp_t *input) {
    for (u32 i = 0; i < input->count; i++) {
        if (input->children[i]->type != NEXP_TYPE_NUMBER) {
            nexp_delete(input);
            return nexp_new_error("(* ...) unsupported type");
        }
    }

    nexp_t *result = nexp_pop(input, 0);

    while (input->count) {
        nexp_t *next = nexp_pop(input, 0);
        result->value *= next->value;
    }

    nexp_delete(input);
    return result;
}

static nexp_t *builtin_slash(nexp_t *input) {
    for (u32 i = 0; i < input->count; i++) {
        if (input->children[i]->type != NEXP_TYPE_NUMBER) {
            nexp_delete(input);
            return nexp_new_error("(/ ...) unsupported type");
        }
    }

    nexp_t *result = nexp_pop(input, 0);

    while (input->count) {
        nexp_t *next = nexp_pop(input, 0);

        if (next->value == 0) {
            nexp_delete(result);
            nexp_delete(next);
            result = nexp_new_error("quotient can't be 0");
            break;
        }

        result->value *= next->value;
    }

    nexp_delete(input);
    return result;
}

nexp_t *builtin(nexp_t *input, char *func) {
    if (strcmp("list", func) == 0) return builtin_list(input);
    if (strcmp("eval", func) == 0) return builtin_eval(input);
    if (strcmp("+",    func) == 0) return builtin_plus(input);
    if (strcmp("-",    func) == 0) return builtin_minus(input);
    if (strcmp("*",    func) == 0) return builtin_star(input);
    if (strcmp("/",    func) == 0) return builtin_slash(input);

    nexp_delete(input);
    return nexp_new_error("S-expression (%s) is not a function on this scope", func);
}
