#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include "nexp.h"

static void nexp_print_(nexp_t *);
static void nexp_print_expr(nexp_t *, char, char);

static nexp_t *new_nexp() {
    nexp_t* result = malloc(sizeof(nexp_t));
    memset(result, 0, sizeof(nexp_t));
    return result;
}

static char *new_string(const char *s){
    size_t string_size = strlen(s) + 1;
    char *result = malloc(string_size);
    memset(result, 0, string_size);
    return result;
}

static void nexp_print_(nexp_t *nexp) {
    // Make sure I'm handling all new types of NLISP-Expressions
    // TODO: <proc> print is vague. I need to add some kind of description.
    // Also allow the user to describe their functions and variables.
    switch (nexp->type) {
        case NEXP_TYPE_NUMBER: printf("%li", nexp->value); break;
        case NEXP_TYPE_ERROR: printf("Error: %s", nexp->error); break;
        case NEXP_TYPE_SYMBOL: printf("%s", nexp->symbol); break;
        case NEXP_TYPE_PROC: printf("<proc>"); break;
        case NEXP_TYPE_SEXPR: nexp_print_expr(nexp, '(', ')'); break;
        case NEXP_TYPE_BEXPR: nexp_print_expr(nexp, '{', '}'); break;
        case NEXP_TYPE_COUNT: break;
    }
}

static void nexp_print_expr(nexp_t *nexp, char open, char close) {
    putchar(open);
    for (i32 i = 0; i < nexp->count; i++) {
        nexp_print_(nexp->children[i]);
        if (i != (nexp->count-1)) putchar(' ');
    }
    putchar(close);
}

void nexp_print(nexp_t *nexp) {
    nexp_print_(nexp);
    putchar('\n');
}

void nexp_delete(nexp_t *nexp) {
    switch (nexp->type) {
        case NEXP_TYPE_COUNT: break;

        // No specific field dealloc
        case NEXP_TYPE_NUMBER: break;
        case NEXP_TYPE_PROC: break;

        // Deallocate strings from errors and symbols
        case NEXP_TYPE_ERROR: free(nexp->error); break;
        case NEXP_TYPE_SYMBOL: free(nexp->symbol); break;

        // S-Expression need deallocation of its children and the dynamic array
        case NEXP_TYPE_SEXPR:
        case NEXP_TYPE_BEXPR: {
            for (u32 i = 0; i < nexp->count; i++)
                nexp_delete(nexp->children[i]);

            free(nexp->children);
        } break;
    }

    free(nexp);
}

nexp_t *nexp_add(nexp_t *parent, nexp_t *child) {
    parent->count++;
    parent->children = realloc(parent->children, sizeof(nexp_t*) * parent->count);
    parent->children[parent->count - 1] = child;
    return parent;
}

nexp_t *nexp_join(nexp_t* a, nexp_t *b) {
    while (b->count)
        a = nexp_add(a, nexp_pop(b, 0));
    nexp_delete(b);
    return a;
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
    nexp_delete(nexp);
    return result;
}

nexp_t *nexp_copy(nexp_t *orig) {
    nexp_t *copy = new_nexp();
    copy->type = orig->type;

    switch (copy->type) {
        case NEXP_TYPE_COUNT: break;
        case NEXP_TYPE_NUMBER: {
            copy->value = orig->value;
        } break;
        case NEXP_TYPE_PROC: {
            copy->proc = orig->proc;
        } break;
        case NEXP_TYPE_ERROR: {
            copy->error = new_string(orig->error);
            strcpy(copy->error, orig->error);
        } break;
        case NEXP_TYPE_SYMBOL: {
            copy->symbol = new_string(orig->symbol);
            strcpy(copy->symbol, orig->symbol);
        } break;
        case NEXP_TYPE_BEXPR:
        case NEXP_TYPE_SEXPR: {
            copy->count = orig->count;
            copy->children = malloc(sizeof(nexp_t *) * copy->count);
            for (u32 i = 0; i < copy->count; i++)
                copy->children[i] = nexp_copy(orig->children[i]);
        } break;
    }

    return copy;
}

nexp_t *nexp_new_number(i64 value) {
    nexp_t *result = new_nexp();
    result->type = NEXP_TYPE_NUMBER;
    result->value = value;
    return result;
}

nexp_t *nexp_new_error(const char *format, ...) {
    nexp_t *result = new_nexp();
    va_list args;
    result->type = NEXP_TYPE_ERROR;
    result->error = new_string(format);
    va_start(args, format);
    vsprintf(result->error, format, args);
    va_end(args);
    return result;
}

nexp_t *nexp_new_symbol(const char *name) {
    nexp_t *result = new_nexp();
    result->type = NEXP_TYPE_SYMBOL;
    result->symbol = new_string(name);
    strcpy(result->symbol, name);
    return result;
}

nexp_t *nexp_new_proc(nexp_proc proc) {
    nexp_t *result = new_nexp();
    result->type = NEXP_TYPE_PROC;
    result->proc = proc;
    return result;
}

nexp_t *nexp_new_Sexpr() {
    nexp_t *result = new_nexp();
    result->type = NEXP_TYPE_SEXPR;
    result->count = 0;
    result->children = NULL;
    return result;
}

nexp_t *nexp_new_Bexpr() {
    nexp_t *result = new_nexp();
    result->type = NEXP_TYPE_BEXPR;
    result->count = 0;
    result->children = NULL;
    return result;
}
