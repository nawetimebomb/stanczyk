#ifndef NLISP_NEXP_H
#define NLISP_NEXP_H

#include "intrinsics.h"
#include "types.h"

typedef struct nexp_t nexp_t;

typedef enum {
    NEXP_TYPE_NUMBER,
    NEXP_TYPE_ERROR,
    NEXP_TYPE_SYMBOL,
    NEXP_TYPE_SEXPR,
    NEXP_TYPE_COUNT
} nexp_type_t;

struct nexp_t {
    nexp_type_t type;
    char *error;
    char *symbol;
    i64 value;
    u32 count;
    nexp_t **children;
};

void nexp_print(nexp_t *nexp);
void delete_nexp(nexp_t *);

nexp_t *nexp_new_number(i64);
nexp_t *nexp_new_error(const char *);
nexp_t *nexp_new_symbol(const char *);
nexp_t *nexp_new_sexpr();
nexp_t *nexp_pop(nexp_t *nexp, u32 i);
nexp_t *nexp_take(nexp_t *nexp, u32 i);

#endif
