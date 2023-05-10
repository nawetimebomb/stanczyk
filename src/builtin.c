#include <string.h>
#include "builtin.h"
#include "nexp.h"

nexp_t *run_builtin_operator(nexp_t *input, char *operator) {
    for (u32 i = 0; i < input->count; i++) {
        if (input->children[i]->type != NEXP_TYPE_NUMBER) {
            delete_nexp(input);
            return nexp_new_error("can't operate on non-numbers");
        }
    }

    nexp_t *result = nexp_pop(input, 0);

    // Transform number to negative if something like (- 5) is given.
    if ((strcmp(operator, "-") == 0) && input->count == 0) {
        result->value = -result->value;
    }

    while (input->count > 0) {
        nexp_t *next = nexp_pop(input, 0);

        if (strcmp(operator, "+") == 0) result->value += next->value;
        if (strcmp(operator, "-") == 0) result->value -= next->value;
        if (strcmp(operator, "*") == 0) result->value *= next->value;
        if (strcmp(operator, "/") == 0) {
            if (next->value == 0) {
                delete_nexp(result);
                delete_nexp(next);
                result = nexp_new_error("quotient can't be 0"); break;
            }
            result->value /= next->value;
        }

        delete_nexp(next);
    }

    delete_nexp(input);
    return result;
}
