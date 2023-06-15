#ifndef NLISP_COMPILER_H
#define NLISP_COMPILER_H

#include "object.h"
#include "vm.h"
#include "chunk.h"

procedure_t *compile(const char *source);

#endif
