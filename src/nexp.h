#ifndef NLISP_NEXP_H
#define NLISP_NEXP_H

#include "types.h"
#include "intrinsics.h"

typedef struct scope_t scope_t;

typedef struct nexp_t nexp_t;
typedef nexp_t *(*nexp_proc)(scope_t *, nexp_t *);

typedef enum {
    NEXP_TYPE_NUMBER,
    NEXP_TYPE_ERROR,
    NEXP_TYPE_SYMBOL,
    NEXP_TYPE_PROC,
    NEXP_TYPE_SEXPR,
    NEXP_TYPE_BEXPR,
    NEXP_TYPE_COUNT
} nexp_type_t;

struct nexp_t {
    nexp_type_t type;
    char *error;
    char *symbol;
    nexp_proc proc;
    i64 value;
    u32 count;
    nexp_t **children;
};

nexp_t *nexp_new_number(i64);
nexp_t *nexp_new_error(const char *, ...);
nexp_t *nexp_new_symbol(const char *);
nexp_t *nexp_new_proc(nexp_proc proc);
nexp_t *nexp_new_Sexpr();
nexp_t *nexp_new_Bexpr();

nexp_t *nexp_add(nexp_t *, nexp_t *);
nexp_t *nexp_join(nexp_t *, nexp_t *);
nexp_t *nexp_pop(nexp_t *, u32);
nexp_t *nexp_take(nexp_t *, u32);
void   nexp_print(nexp_t *);
void   nexp_delete(nexp_t *);
nexp_t *nexp_copy(nexp_t *);

#endif
