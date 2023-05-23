#include <stdlib.h>

#include "compiler.h"
#include "memory.h"
#include "object.h"
#include "value.h"
#include "table.h"
#include "vm.h"

#ifdef DEBUG_LOG_GC
#include <stdio.h>
#include "debug.h"
#endif

extern VM_t VM;

#define GC_HEAP_GROW_FACTOR 2

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
    VM.bytes_alloc += new_size - prev_size;

    if (new_size > prev_size) {
#ifdef DEBUG_STRESS_GC
        collect_garbage();
#endif
        if (VM.bytes_alloc > VM.next_gc) {
            collect_garbage();
        }
    }

    if (new_size == 0) {
        free(pointer);
        return NULL;
    }

    void *result = realloc(pointer, new_size);
    if (result == NULL) exit(1);
    return result;
}

void mark_object(obj_t *object) {
    if (object == NULL) return;
    if (object->marked) return;

#ifdef DEBUG_LOG_GC
    printf("%p mark ", (void *)object);
    print_value(OBJ_VAL(object));
    printf("\n");
#endif

    object->marked = true;

    if (VM.gray_capacity < VM.gray_count + 1) {
        VM.gray_capacity = GROW_CAPACITY(VM.gray_capacity);
        VM.gray_stack = (obj_t **)realloc(VM.gray_stack, sizeof(obj_t *) * VM.gray_capacity);
        // TODO: Handle this error gracefully, not just crash the app.
        if (VM.gray_stack == NULL) exit(1);
    }

    VM.gray_stack[VM.gray_count++] = object;
}

void mark_value(value_t value) {
    if (IS_OBJ(value)) mark_object(AS_OBJ(value));
}

static void mark_array(value_array_t *array) {
    for (int i = 0; i < array->count; i++) {
        mark_value(array->values[i]);
    }
}

static void blacken_object(obj_t *object) {
#ifdef DEBUG_LOG_GC
    printf("%p blacken ", (void *)object);
    print_value(OBJ_VAL(object));
    printf("\n");
#endif
    switch (object->type) {
        case OBJ_PROCEDURE: {
            procedure_t *procedure = (procedure_t *)object;
            mark_object((obj_t *)procedure->name);
            mark_array(&procedure->chunk.constants);
        } break;
        case OBJ_LIST: {
            list_t *list = (list_t *)object;
            for (int i = 0; i < list->count; i++) {
                mark_value(list->content[i]);
            }
        } break;
        case OBJ_NATIVE:
        case OBJ_STRING:
            break;
    }
}

static void free_object(obj_t *object) {
#ifdef DEBUG_LOG_GC
    printf("%p free type %d\n", (void *)object, object->type);
#endif

    switch (object->type) {
        case OBJ_PROCEDURE: {
            procedure_t *procedure = (procedure_t *)object;
            free_chunk(&procedure->chunk);
            FREE(procedure_t, object);
        } break;
        case OBJ_NATIVE: FREE(native_t, object); break;
        case OBJ_LIST: {
            list_t *list = (list_t *)object;
            FREE_ARRAY(value_t *, list->content, list->count);
            FREE(list_t, object);
        } break;
        case OBJ_STRING: {
            string_t *string = (string_t *)object;
            FREE_ARRAY(char, string->chars, string->length + 1);
            FREE(string_t, object);
        } break;
    }
}

static void mark_roots() {
    for (value_t *slot = VM.stack; slot < VM.stack_top; slot++) {
        mark_value(*slot);
    }

    mark_table(&VM.symbols);
    mark_compiler_roots();
}

static void trace_references() {
    while (VM.gray_count > 0) {
        obj_t *object = VM.gray_stack[--VM.gray_count];
        blacken_object(object);
    }
}

static void sweep() {
    obj_t *previous = NULL;
    obj_t *object = VM.objects;

    while (object != NULL) {
        if (object->marked) {
            object->marked = false;
            previous = object;
            object = object->next;
        } else {
            obj_t *unreached = object;
            object = object->next;
            if (previous != NULL) {
                previous->next = object;
            } else {
                VM.objects = object;
            }

            free_object(unreached);
        }
    }
}

void collect_garbage() {
#ifdef DEBUG_LOG_GC
    printf("-- gc begin\n");
    size_t before = VM.bytes_alloc;
#endif

    mark_roots();
    trace_references();
    table_remove_white(&VM.strings);
    sweep();

    VM.next_gc = VM.bytes_alloc * GC_HEAP_GROW_FACTOR;

#ifdef DEBUG_LOG_GC
    printf("-- gc end\n");
    printf("    collected %zu bytes (from %zu to %zu) next at %zu\n",
           before - VM.bytes_alloc, before, VM.bytes_alloc, VM.next_gc);
#endif
}

void free_objects() {
    obj_t *object = VM.objects;
    while (object != NULL) {
        obj_t *next = object->next;
        free_object(object);
        object = next;
    }

    free(VM.gray_stack);
}
