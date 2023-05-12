#include <string.h>
#include "includes/mpc.h"
#include "builtin.h"
#include "eval.h"
#include "parser.h"
#include "nexp.h"
#include "intrinsics.h"
#include "scope.h"

#define COMPARE_ELEMENTS_COUNT 2
#define IF_ELEMENTS_COUNT 3

// TODO: Add documentation

/* Usage: (list <arguments>)
 *   <arguments>: Any type.
 *   Description: Modifies the input arguments and transform it into a B-expression.
 *   Example: (list 1 2 3 4) -> {1 2 3 4}                                               */
static nexp_t *b_list(scope_t *scope, nexp_t *input) {
    nexp_t *output = input;
    output->type = NEXP_TYPE_BEXPR;
    return output;
}

// Gets a B-expression of multiple S-expressions
// (eval {(print (+ 1 2)) (print (+ 3 4))})
static nexp_t*b_eval(scope_t *scope, nexp_t *input) {
    for (u32 i = 0; i < input->count; i++) {
        NASSERT(input, input->children[i]->type == NEXP_TYPE_SEXPR,
                "eval got incorrect argument", NULL);
    }
    nexp_t *result;
    while (input->count)
        result = eval_nexp(scope, nexp_pop(input, 0));
    nexp_delete(input);
    return result;
}

static nexp_t *b_load(scope_t *scope, nexp_t *input) {
    NASSERT(input, input->count == 1,
            "invalid number of arguments\n"
            "\t-> Given: %d\n"
            "\t-> Expected: %d",
            input->count, 1);
    NASSERT(input, input->children[0]->type == NEXP_TYPE_STRING,
            "invalid argument type\n"
            "\t-> Given: %s\n"
            "\t-> Expected: %s",
            nexp_describe_type(input->children[0]->type),
            nexp_describe_type(NEXP_TYPE_STRING));

    mpc_result_t r;

    if (mpc_parse_contents(input->children[0]->string,
                           get_parser_type(NEXP_PARSER_TYPE_NEXP),
                           &r)) {
        nexp_t *expr = parse_expr(r.output);
        mpc_ast_delete(r.output);

        while (expr->count) {
            nexp_t *result = eval_nexp(scope, nexp_add(nexp_new_Sexpr(), nexp_pop(expr, 0)));
            if (result->type == NEXP_TYPE_ERROR) { nexp_print(result); }
            nexp_delete(result);
        }

        nexp_delete(expr);
        nexp_delete(input);

        return nexp_new_Sexpr();
    } else {
        char *error_message = mpc_err_string(r.error);
        mpc_err_delete(r.error);

        nexp_t *error = nexp_new_error("failed loading library %s", error_message);
        free(error_message);
        nexp_delete(input);

        return error;
    }
}

static nexp_t *b_print(scope_t *scope, nexp_t *input) {
    for (u32 i = 0; i < input->count; i++) {
        nexp_print_b(input->children[i]);
        putchar(' ');
    }
    putchar('\n');
    nexp_delete(input);
    return nexp_new_Sexpr();
}

static nexp_t *b_debug(scope_t *scope, nexp_t *input) {
    for (u32 i = 0; i < input->count; i++) {
        printf("%s ", nexp_describe_type(input->children[i]->type));
        nexp_print_b(input->children[i]);
        putchar(' ');
    }
    putchar('\n');
    nexp_delete(input);
    return nexp_new_Sexpr();
}

static nexp_t *b_do(scope_t *scope, nexp_t *input) {
    nexp_t *body = nexp_new_Bexpr();
    while (input->count)
        body = nexp_add(body, nexp_pop(input, 0));
    nexp_delete(input);
    return b_eval(scope, nexp_copy(body));
}

static nexp_t *b_plus(scope_t *scope, nexp_t *input) {
    // Get the first child type, and match it with the other children.
    nexp_type_t eq_type = input->children[0]->type;

    for (u32 i = 0; i < input->count; i++) {
        // TODO: Add the ability to show which type I'm talking about by saving the
        // type on the nexp_t struct. [static types]
        if (input->children[i]->type != NEXP_TYPE_BEXPR &&
            input->children[i]->type != NEXP_TYPE_NUMBER) {
            nexp_delete(input);
            return nexp_new_error("(+ ...) unsupported type");
        }

        if (input->children[i]->type != eq_type) {
            nexp_delete(input);
            return nexp_new_error("(+ ...) can't mix and match types");
        }
    }

    nexp_t *result = nexp_pop(input, 0);

    switch (eq_type) {
        case NEXP_TYPE_NUMBER: {
            while (input->count > 0) {
                nexp_t *next = nexp_pop(input, 0);
                result->value += next->value;
            }
        } break;
        case NEXP_TYPE_BEXPR: {
            while (input->count)
                result = nexp_join(result, nexp_pop(input, 0));
        } break;
        // The rest of the types are skipped.
        default: break;
    }

    nexp_delete(input);
    return result;
}

static nexp_t *b_minus(scope_t *scope, nexp_t *input) {
    for (u32 i = 0; i < input->count; i++) {
        if (input->children[i]->type != NEXP_TYPE_NUMBER) {
            nexp_delete(input);
            return nexp_new_error("(- ...) unsupported type");
        }
    }

    nexp_t *result = nexp_pop(input, 0);

    while (input->count)  {
        nexp_t *next = nexp_pop(input, 0);
        result->value -= next->value;
    }

    nexp_delete(input);
    return result;
}

static nexp_t *b_star(scope_t *scope, nexp_t *input) {
    for (u32 i = 0; i < input->count; i++) {
        if (input->children[i]->type != NEXP_TYPE_NUMBER) {
            nexp_delete(input);
            return nexp_new_error("(* ...) unsupported type");
        }
    }

    nexp_t *result = nexp_pop(input, 0);

    while (input->count) {
        nexp_t *next = nexp_pop(input, 0);
        result->value *= next->value;
    }

    nexp_delete(input);
    return result;
}

static nexp_t *b_slash(scope_t *scope, nexp_t *input) {
    for (u32 i = 0; i < input->count; i++) {
        if (input->children[i]->type != NEXP_TYPE_NUMBER) {
            nexp_delete(input);
            return nexp_new_error("(/ ...) unsupported type");
        }
    }

    nexp_t *result = nexp_pop(input, 0);

    while (input->count) {
        nexp_t *next = nexp_pop(input, 0);

        if (next->value == 0) {
            nexp_delete(result);
            nexp_delete(next);
            result = nexp_new_error("quotient can't be 0");
            break;
        }

        result->value *= next->value;
    }

    nexp_delete(input);
    return result;
}

static nexp_t *b_compare_ordering(scope_t *scope, nexp_t *input, char *operator) {
    NASSERT(input, input->count == COMPARE_ELEMENTS_COUNT,
            "comparison can only be done between two elements.\n"
            "\t-> Given: %d\n"
            "\t-> Expected: %d",
            input->count, COMPARE_ELEMENTS_COUNT);

    for (u8 i = 0; i < COMPARE_ELEMENTS_COUNT; i++) {
        NASSERT(input, input->children[i]-> type == NEXP_TYPE_NUMBER,
                "element %d is not a number", i + 1);
    }

    u8 result;

    if (strcmp(operator, ">") == 0)
        result = (input->children[0]->value > input->children[1]->value);
    if (strcmp(operator, "<=") == 0)
        result = (input->children[0]->value <= input->children[1]->value);
    if (strcmp(operator, "<") == 0)
        result = (input->children[0]->value < input->children[1]->value);
    if (strcmp(operator, ">=") == 0)
        result = (input->children[0]->value >= input->children[1]->value);

    nexp_delete(input);
    return nexp_new_number(result);
}

static u8 b_compare_these(nexp_t *left, nexp_t *right) {
    // Assuming both types are the same since we compare them before calling this function.
    switch (left->type) {
        case NEXP_TYPE_NUMBER: return (left->value == right->value);
        case NEXP_TYPE_STRING: return strcmp(left->string, right->string) == 0;
        case NEXP_TYPE_BEXPR: {
            if (left->count != right->count) return 0;

            // Compare each element, return 0 if any of the elements are different.
            for (u32 i = 0; i < left->count; i++)
                if (!b_compare_these(left->children[i], right->children[i])) return 0;

            return 1;
        } break;
        case NEXP_TYPE_ERROR:
        case NEXP_TYPE_SYMBOL:
        case NEXP_TYPE_PROC:
        case NEXP_TYPE_SEXPR:
        case NEXP_TYPE_COUNT:
            break;
    }

    return 0;
}

static nexp_t *b_compare_equals(scope_t *scope, nexp_t *input, char *operator) {
    NASSERT(input, input->count == COMPARE_ELEMENTS_COUNT,
            "comparison can only be done between two elements.\n"
            "\t-> Given: %d\n"
            "\t-> Expected: %d",
            input->count, COMPARE_ELEMENTS_COUNT);
    NASSERT(input, input->children[0]->type == input->children[1]->type,
            "type of left and right elements are different\n"
            "\t->Left: %s\n"
            "\t->Right: %s",
            nexp_describe_type(input->children[0]->type),
            nexp_describe_type(input->children[1]->type));
    // TODO: Check we only allow to compare for specific types.

    u8 result = b_compare_these(input->children[0], input->children[1]);

    if (strcmp(operator, "!=") == 0)
        result = !result;

    nexp_delete(input);
    return nexp_new_number(result);
}

static nexp_t *b_less(scope_t *scope, nexp_t *input) {
    return b_compare_ordering(scope, input, "<");
}

static nexp_t *b_less_equal(scope_t *scope, nexp_t *input) {
    return b_compare_ordering(scope, input, "<=");
}

static nexp_t *b_more(scope_t *scope, nexp_t *input) {
    return b_compare_ordering(scope, input, ">");
}

static nexp_t *b_more_equal(scope_t *scope, nexp_t *input) {
    return b_compare_ordering(scope, input, ">=");
}

static nexp_t *b_equal(scope_t *scope, nexp_t *input) {
    return b_compare_equals(scope, input, "==");
}

static nexp_t *b_not_equal(scope_t *scope, nexp_t *input) {
    return b_compare_equals(scope, input, "!=");
}

static nexp_t *b_if(scope_t *scope, nexp_t *input) {
    NASSERT(input, input->count == 3,
            "incorrect number of elements passed into if expression\n"
            "\t->Given: %d\n"
            "\t->Expected: %d",
            input->count, IF_ELEMENTS_COUNT);
    NASSERT(input, input->children[0]->type == NEXP_TYPE_NUMBER ||
            input->children[0]->type == NEXP_TYPE_SEXPR,
            "incorrect type in first element for if expression\n"
            "\t->Given: %d\n"
            "\t->Expected: %d",
            nexp_describe_type(input->children[0]->type),
            nexp_describe_type(NEXP_TYPE_NUMBER));
    NASSERT(input, input->children[1]->type == NEXP_TYPE_SEXPR ||
            input->children[1]->type == NEXP_TYPE_BEXPR,
            "incorrect type in second element for if expression\n"
            "\t->Given: %d\n"
            "\t->Expected: %d",
            nexp_describe_type(input->children[1]->type),
            nexp_describe_type(NEXP_TYPE_SEXPR));
    NASSERT(input, input->children[2]->type == NEXP_TYPE_SEXPR ||
            input->children[2]->type == NEXP_TYPE_BEXPR,
            "incorrect type in third element for if expression\n"
            "\t->Given: %d\n"
            "\t->Expected: %d",
            nexp_describe_type(input->children[2]->type),
            nexp_describe_type(NEXP_TYPE_SEXPR));

    nexp_t *condition = eval_nexp(scope, input->children[0]);

    // Container for the S-expression that is going to be evaluated (if or else)
    nexp_t *result;
    input->children[1]->type = NEXP_TYPE_SEXPR;
    input->children[2]->type = NEXP_TYPE_SEXPR;

    if (condition->value)
        result = eval_nexp(scope, nexp_pop(input, 1));
    else
        result = eval_nexp(scope, nexp_pop(input, 2));

    nexp_delete(input);
    return result;
}

static nexp_t *b_define(scope_t *scope, nexp_t *input) {
    // TODO: Need to get rid of result in case we get errors, otherwise this is surely a
    // a memory leak :^)
    nexp_t *result = eval_nexp(scope, nexp_new_Sexpr());

    // TODO: Add proper error messages per every case.
    // We need to wait until the define proc is pretty much done to figure out
    // how we can report errors in these scenarios.
    if (input->count == 2) {
        // Defining a variable.
        // A variable definition can have single or multiple assigments. To do
        // single assigment, the user provides a symbol as the first element,
        // and anything as the second.
        // I.e. (: my_var 13) || (: my_var { 1 2 3 })
        // To do multiple assigments, the user may provide a B-expression as
        // both the first and second element.
        // I.e. (: { my var is } { 1 2 3 })
        nexp_t *expr = nexp_pop(input, 0);

        // For single assigment of `var` `(any type) value`...
        if (expr->type == NEXP_TYPE_SYMBOL) {
            nexp_t *value = nexp_pop(input, 0);
            scope_put(scope, expr, value);
            nexp_delete(expr);
            nexp_delete(value);
            nexp_delete(input);
            return result;
        }

        // For multiple assigments
        if (expr->type == NEXP_TYPE_BEXPR) {
            nexp_t *value = nexp_pop(input, 0);

            NASSERT(input, value->type == NEXP_TYPE_BEXPR,
                    "only B-expressions are allowed to be used in B-expression assigments.\n"
                    "\t-> Given: %s\n"
                    "\t-> Expected: %s",
                    nexp_describe_type(value->type), nexp_describe_type(NEXP_TYPE_BEXPR));

            NASSERT(input, expr->count == value->count,
                    "mismatching number of assigments.\n"
                    "\t-> Symbols: %d\n"
                    "\t-> Values: %d",
                    expr->count, value->count);

            for (u32 i = 0; i < expr->count; i++) {
                scope_put(scope, expr->children[i], value->children[i]);
            }
            nexp_delete(expr);
            nexp_delete(value);
            nexp_delete(input);
            return result;
        }
    }

    // TODO: Basic error if every case fails somehow. This needs to get improved after the
    // define proc is complete.
    return nexp_new_error("couldn't handle definition");
}

static nexp_t *b_define_const(scope_t *scope, nexp_t *input) {
    return nexp_new_error("Not implemented :^)");
}

static nexp_t *b_define_proc(scope_t *scope, nexp_t *input) {
    // TODO: Check types and error
    nexp_t *expr = nexp_pop(input, 0);
    nexp_t *arguments = nexp_pop(input, 0);
    nexp_t *body = nexp_new_Bexpr();

    while (input->count) {
        nexp_t *sexpr = nexp_new_Sexpr();
        sexpr = nexp_add(sexpr, nexp_pop(input, 0));
        body = nexp_join(body, sexpr);
    }

    nexp_t *proc = nexp_new_proc(arguments, body);
    scope_put(scope, expr, proc);
    return proc;
}

static void add_builtin_internal(scope_t *scope, char *name,
                                 nexp_internal internal, nexp_mode_t mode) {
    nexp_t *expr = nexp_new_symbol(name);
    nexp_t *value = nexp_new_internal(internal);
    value->mode = mode;
    scope_put(scope, expr, value);
    nexp_delete(expr);
    nexp_delete(value);
}

nexp_t *call_proc(scope_t *scope, nexp_t *procedure, nexp_t *input) {
    if (procedure->internal) return procedure->internal(scope, input);

    u32 num_of_arguments = procedure->arguments->count;

    while (input->count) {
        nexp_t *expr = nexp_pop(procedure->arguments, 0);

        // Checking for variable arguments
        if (strcmp(expr->symbol, "&") == 0) {
            NASSERT(input, procedure->arguments->count == 1,
                    "invalid arguments on procedure.\n"
                    "Symbol '&' not followed by a single symbol.", NULL);

            nexp_t *rest = nexp_pop(procedure->arguments, 0);
            scope_put(procedure->scope, rest, b_list(scope, input));
            nexp_delete(expr);
            nexp_delete(rest);
            break;
        }

        nexp_t *value  = nexp_pop(input, 0);
        scope_put(procedure->scope, expr, value);
        nexp_delete(expr);
        nexp_delete(value);
    }

    nexp_delete(input);

    // If the user didn't provide any variable arguments, then add empty B-expression
    if (procedure->arguments->count > 0 &&
        strcmp(procedure->arguments->children[0]->symbol, "&") == 0) {
        NASSERT(input, procedure->arguments->count == 2,
                "invalid arguments on procedure.\n"
                "Symbol '&' not followed by a single symbol.", NULL);

        nexp_delete(nexp_pop(procedure->arguments, 0));
        nexp_t *expr = nexp_pop(procedure->arguments, 0);
        nexp_t *value = nexp_new_Bexpr();

        scope_put(procedure->scope, expr, value);
        nexp_delete(expr);
        nexp_delete(value);
    }

    // If no argument bindings are left, then success.
    if (procedure->arguments->count == 0) {
        procedure->scope->parent = scope;

        return b_eval(procedure->scope, nexp_copy(procedure->body));
    } else {
        return nexp_new_error("mismatch number of arguments\n"
                              "\t->Given: %d\n"
                              "\t->Expected: %d",
                              input->count, num_of_arguments);
    }
}

nexp_t *load_from_file(scope_t *scope, nexp_t *input) {
    return b_load(scope, input);
}

void init_builtins(scope_t *scope) {
    // Native functions
    add_builtin_internal(scope, "eval",  b_eval,         NEXP_MODE_DEFAULT);
    add_builtin_internal(scope, "list",  b_list,         NEXP_MODE_DEFAULT);
    add_builtin_internal(scope, "load",  b_load,         NEXP_MODE_DEFAULT);
    add_builtin_internal(scope, "print", b_print,        NEXP_MODE_DEFAULT);
    add_builtin_internal(scope, "debug", b_debug,        NEXP_MODE_DEFAULT);
    add_builtin_internal(scope, "do",    b_do,           NEXP_MODE_IMMEDIATE);

    // Arithmetic operators
    add_builtin_internal(scope, "+",     b_plus,         NEXP_MODE_DEFAULT);
    add_builtin_internal(scope, "-",     b_minus,        NEXP_MODE_DEFAULT);
    add_builtin_internal(scope, "*",     b_star,         NEXP_MODE_DEFAULT);
    add_builtin_internal(scope, "/",     b_slash,        NEXP_MODE_DEFAULT);

    // Ordering and comparing
    add_builtin_internal(scope, "<",     b_less,         NEXP_MODE_DEFAULT);
    add_builtin_internal(scope, "<=",    b_less_equal,   NEXP_MODE_DEFAULT);
    add_builtin_internal(scope, ">",     b_more,         NEXP_MODE_DEFAULT);
    add_builtin_internal(scope, ">=",    b_more_equal,   NEXP_MODE_DEFAULT);
    add_builtin_internal(scope, "==",    b_equal,        NEXP_MODE_DEFAULT);
    add_builtin_internal(scope, "!=",    b_not_equal,    NEXP_MODE_DEFAULT);
    add_builtin_internal(scope, "if",    b_if,           NEXP_MODE_IMMEDIATE);

    // Declaration and definition
    add_builtin_internal(scope, ":",     b_define,       NEXP_MODE_VAR_DECLARATION);
    add_builtin_internal(scope, "::",    b_define_const, NEXP_MODE_CONST_DECLARATION);
    add_builtin_internal(scope, "proc",  b_define_proc,  NEXP_MODE_PROC_DECLARATION);
}
