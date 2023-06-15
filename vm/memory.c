#include <stdlib.h>

#include "memory.h"

/* reallocate:
 *    reallocates or frees memory depending the following conditions:
 *    |-----------|----------|----------------------------------|
 *    | prev_size | new_size | Operation                        |
 *    |-----------|----------|----------------------------------|
 *    | 0         | non-zero | allocates a new block of memory  |
 *    | non-zero  | 0        | free allocation                  |
 *    | non-zero  | v < prev | shrink existing allocation       |
 *    | non-zero  | v > prev | grow existing allocation         |
 *    |-----------|----------|----------------------------------|
 *
 *    note: use this with the `GROW_ARRAY` or `FREE_ARRAY` macros
 */
void *reallocate(void *pointer, size_t prev_size, size_t new_size) {
    if (new_size == 0) {
        free(pointer);
        return NULL;
    }

    void *result = realloc(pointer, new_size);
    if (result == NULL) exit(1);
    return result;
}
