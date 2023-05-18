#ifndef STANCZYK_NATIVES_H
#define STANCZYK_NATIVES_H

#include "object.h"

typedef void (*define_native_func)(const char *name, native_proc_t procedure, int arg_count);

void register_natives(define_native_func define);

#endif
