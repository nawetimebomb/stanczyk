#include <stdlib.h>
#include <string.h>
#include "nexp.h"

static char *new_string(const char *s){
    size_t string_size = strlen(s) + 1;
    char *result = malloc(string_size);
    return result;
}

static void nexp_print_sexpr(nexp_t *nexp, char open, char close) {
    putchar(open);
    for (i32 i = 0; i < nexp->count; i++) {
        nexp_print(nexp->children[i]);
        if (i != (nexp->count-1)) putchar(' ');
    }
    putchar(close);
}

void nexp_print(nexp_t *nexp) {
    // Make sure I'm handling all new types of NLISP-Expressions
    assert(4 == NEXP_TYPE_COUNT);
    switch (nexp->type) {
        case NEXP_TYPE_NUMBER: printf("%li\n", nexp->value); break;
        case NEXP_TYPE_ERROR: printf("Error: %s\n", nexp->error); break;
        case NEXP_TYPE_SYMBOL: printf("%s\n", nexp->symbol); break;
        case NEXP_TYPE_SEXPR: nexp_print_sexpr(nexp, '(', ')'); break;
        case NEXP_TYPE_COUNT: break;
    }
}

void delete_nexp(nexp_t *nexp) {
    // Make sure I handle all deallocations of types.
    assert(4 == NEXP_TYPE_COUNT);
    switch (nexp->type) {
        case NEXP_TYPE_COUNT: break;

        // General deallocation of numbers is fine, we don't allocate specific fields.
        case NEXP_TYPE_NUMBER: break;

        // Deallocate strings from errors and symbols
        case NEXP_TYPE_ERROR: free(nexp->error); break;
        case NEXP_TYPE_SYMBOL: free(nexp->symbol); break;

        // S-Expression need deallocation of its children and the dynamic array
        case NEXP_TYPE_SEXPR: {
            for (u32 i = 0; i < nexp->count; i++)
                delete_nexp(nexp->children[i]);

            free(nexp->children);
        } break;
    }

    free(nexp);
}

nexp_t *nexp_new_number(i64 value) {
    nexp_t *result = malloc(sizeof(nexp_t));
    result->type = NEXP_TYPE_NUMBER;
    result->value = value;
    return result;
}

nexp_t *nexp_new_error(const char *message) {
    nexp_t *result = malloc(sizeof(nexp_t));
    result->type = NEXP_TYPE_ERROR;
    result->error = new_string(message);
    strcpy(result->error, message);
    return result;
}

nexp_t *nexp_new_symbol(const char *name) {
    nexp_t *result = malloc(sizeof(nexp_t));
    result->type = NEXP_TYPE_SYMBOL;
    result->symbol = new_string(name);
    strcpy(result->symbol, name);
    return result;
}

nexp_t *nexp_new_sexpr() {
    nexp_t *result = malloc(sizeof(nexp_t));
    result->type = NEXP_TYPE_SEXPR;
    result->count = 0;
    result->children = NULL;
    return result;
}

nexp_t *nexp_pop(nexp_t *nexp, u32 i) {
    nexp_t * result = nexp->children[i];

    // Shift the memory, decrease the count and reallocate.
    memmove(&nexp->children[i], &nexp->children[i+1], sizeof(nexp_t*) * (nexp->count-i-1));
    nexp->count--;
    nexp->children = realloc(nexp->children, sizeof(nexp_t*) * nexp->count);

    return result;
}

nexp_t *nexp_take(nexp_t *nexp, u32 i) {
    nexp_t *result = nexp_pop(nexp, i);
    delete_nexp(nexp);
    return result;
}
