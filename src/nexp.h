#ifndef NLISP_NEXP_H
#define NLISP_NEXP_H

#include "types.h"
#include "intrinsics.h"

typedef struct scope_t scope_t;

typedef struct nexp_t nexp_t;
typedef nexp_t *(*nexp_internal)(scope_t *, nexp_t *);

typedef enum {
    NEXP_TYPE_NUMBER,
    NEXP_TYPE_ERROR,
    NEXP_TYPE_SYMBOL,
    NEXP_TYPE_STRING,
    NEXP_TYPE_PROC,
    NEXP_TYPE_SEXPR,
    NEXP_TYPE_BEXPR,
    NEXP_TYPE_COUNT
} nexp_type_t;

typedef enum {
    NEXP_MODE_DEFAULT,
    NEXP_MODE_VAR_DECLARATION,
    NEXP_MODE_CONST_DECLARATION,
    NEXP_MODE_PROC_DECLARATION,
    NEXP_MODE_IMMEDIATE,
    NEXP_MODE_INLINE
} nexp_mode_t;

struct nexp_t {
    nexp_type_t type;
    nexp_mode_t mode;
    char *error;
    char *symbol;
    char *string;
    i64 value;

    nexp_internal internal;
    scope_t *scope;
    nexp_t *arguments;
    nexp_t *body;

    u32 count;
    nexp_t **children;
};

nexp_t *nexp_new_number(i64);
nexp_t *nexp_new_error(const char *, ...);
nexp_t *nexp_new_symbol(const char *);
nexp_t *nexp_new_string(const char *);
nexp_t *nexp_new_internal(nexp_internal);
nexp_t *nexp_new_proc(nexp_t *, nexp_t *);
nexp_t *nexp_new_Sexpr();
nexp_t *nexp_new_Bexpr();

nexp_t *nexp_add(nexp_t *, nexp_t *);
nexp_t *nexp_join(nexp_t *, nexp_t *);
nexp_t *nexp_pop(nexp_t *, u32);
nexp_t *nexp_take(nexp_t *, u32);
void   nexp_print(nexp_t *);
void   nexp_print_b(nexp_t *);
void   nexp_delete(nexp_t *);
nexp_t *nexp_copy(nexp_t *);
char   *nexp_describe_type(nexp_type_t);

#endif
