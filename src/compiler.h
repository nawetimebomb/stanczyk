#ifndef STANCZYK_COMPILER_H
#define STANCZYK_COMPILER_H

#include "object.h"
#include "vm.h"
#include "chunk.h"

procedure_t *compile(const char *source);
void mark_compiler_roots();

#endif
