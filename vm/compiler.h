#ifndef NLISP_COMPILER_H
#define NLISP_COMPILER_H

#include "chunk.h"

bool compile(const char *source, chunk_t *chunk);

#endif
