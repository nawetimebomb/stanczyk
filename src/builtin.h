#ifndef NLISP_BUILTIN_H
#define NLISP_BUILTIN_H

#include "nexp.h"

nexp_t *run_builtin_operator(nexp_t *input, char *operation);

#endif
