#include <stdio.h>
#include "eval.h"
#include "includes/mpc.h"
#include "intrinsics.h"
#include "nexp.h"
#include "parser.h"

#ifdef _WIN32
#include "cli_windows.h"
#else
    #include <editline/readline.h>
#endif

int main() {
    mpc_parser_t *number   = mpc_new("number");
    mpc_parser_t *symbol   = mpc_new("symbol");
    mpc_parser_t *Sexpr    = mpc_new("Sexpr");
    mpc_parser_t *Bexpr    = mpc_new("Bexpr");
    mpc_parser_t *expr     = mpc_new("expr");

    mpca_lang(MPCA_LANG_DEFAULT,
              "                                                         \
                  number    : /-?[0-9]+/ ;                              \
                  symbol    : \"list\" | \"eval\"                       \
                            | '+' | '-' | '*' | '/' ;                   \
                  Sexpr     : '(' <expr>* ')' ;                         \
                  Bexpr     : '{' <expr>* '}' ;                         \
                  expr      : <number> | <symbol> | <Sexpr> | <Bexpr> ; \
              ", number, symbol, Sexpr, Bexpr, expr);

    puts("Nihilisp REPL v0.1");
    puts("Press Ctrl+C to Exit\n");

    while (1) {
        char *input = readline("> ");
        add_history(input);

        mpc_result_t r;

        if (mpc_parse("<stdin>", input, Sexpr, &r)) {
            nexp_t *result = eval_nexp(parse_expr(r.output));
            nexp_print(result);
            nexp_delete(result);
        } else {
            mpc_err_print(r.error);
            mpc_err_delete(r.error);
        }

        free(input);
    }

    // Make sure I clean up the new types
    assert(5 == NEXP_TYPE_COUNT);
    mpc_cleanup(NEXP_TYPE_COUNT, number, symbol, Sexpr, Bexpr, expr);

    return 0;
}
