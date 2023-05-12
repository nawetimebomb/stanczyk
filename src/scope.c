#include <stdlib.h>
#include <string.h>
#include "scope.h"
#include "nexp.h"

scope_t *scope_new() {
    scope_t *result = malloc(sizeof(scope_t));
    result->count = 0;
    result->parent = NULL;
    result->symbols = NULL;
    result->values = NULL;
    return result;
}

void scope_delete(scope_t *scope) {
    for (u32 i = 0; i < scope->count; i++) {
        free(scope->symbols[i]);
        nexp_delete(scope->values[i]);
    }
    free(scope->symbols);
    free(scope->values);
    free(scope);
}

void scope_put(scope_t *scope, nexp_t *expr, nexp_t *value) {
    // Check for existing symbols in the scope. If found, re-set the value to `value`.
    for (u32 i = 0; i < scope->count; i++) {
        if (strcmp(scope->symbols[i], expr->symbol) == 0) {
            nexp_delete(scope->values[i]);
            scope->values[i] = nexp_copy(value);
            return;
        }
    }

    // If it doesn't, then realloc space for it and set it.
    scope->count++;
    scope->values = realloc(scope->values, sizeof(nexp_t *) * scope->count);
    scope->symbols = realloc(scope->symbols, sizeof(char *) * scope->count);

    scope->values[scope->count - 1] = nexp_copy(value);
    scope->symbols[scope->count - 1] = malloc(strlen(expr->symbol) + 1);
    strcpy(scope->symbols[scope->count - 1], expr->symbol);
}

nexp_t *scope_get(scope_t *scope, nexp_t *nexp) {
    for (u32 i = 0; i < scope->count; i++) {
        if (strcmp(scope->symbols[i], nexp->symbol) == 0)
            return nexp_copy(scope->values[i]);
    }

    if (scope->parent) {
        return scope_get(scope->parent, nexp);
    } else {
        return nexp_new_error("symbol %s not found in scope", nexp->symbol);
    }
}

scope_t *scope_copy(scope_t *orig) {
    scope_t *copy = malloc(sizeof(scope_t));
    copy->parent = orig->parent;
    copy->count = orig->count;
    copy->symbols = malloc(sizeof(char *) * copy->count);
    copy->values = malloc(sizeof(nexp_t *) * copy->count);

    for (u32 i = 0; i < orig->count; i++) {
        copy->symbols[i] = malloc(strlen(orig->symbols[i]) + 1);
        strcpy(copy->symbols[i], orig->symbols[i]);
        copy->values[i] = nexp_copy(orig->values[i]);
    }

    return copy;
}
