#ifndef NLISP_BUILTIN_H
#define NLISP_BUILTIN_H

#include "nexp.h"

nexp_t *call_proc(scope_t *, nexp_t *, nexp_t *);
nexp_t *load_from_file(scope_t *, nexp_t *);
void init_builtins(scope_t *);

#endif
