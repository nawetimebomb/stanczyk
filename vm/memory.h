#ifndef NLISP_MEMORY_H
#define NLISP_MEMORY_H

#include "common.h"

#define MIN_MEM_CAPACITY 8
#define MEM_SCALAR 2

#define GROW_CAPACITY(capacity)                                                \
  ((capacity) < MIN_MEM_CAPACITY ? MIN_MEM_CAPACITY : (capacity)*MEM_SCALAR)

#define GROW_ARRAY(type, pointer, prev_count, new_count)                       \
  (type *)reallocate(pointer, sizeof(type) * (prev_count),                     \
                     sizeof(type) * (new_count))

#define FREE_ARRAY(type, pointer, prev_count)                                  \
  reallocate(pointer, sizeof(type) * (prev_count), 0)

void *reallocate(void *pointer, size_t prev_size, size_t new_size);

#endif
