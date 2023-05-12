#ifndef NLISP_SCOPE_H
#define NLISP_SCOPE_H

#include "types.h"
#include "nexp.h"

struct scope_t {
    u64 count;
    scope_t *parent;
    char **symbols;
    nexp_t **values;
};

scope_t *scope_new();
void scope_delete(scope_t *);
void scope_put(scope_t *, nexp_t *, nexp_t *);
scope_t *scope_copy(scope_t *);
nexp_t *scope_get(scope_t *, nexp_t *);

#endif
