#include <stdio.h>
#include "eval.h"
#include "includes/mpc.h"
#include "intrinsics.h"
#include "nexp.h"
#include "parser.h"
#include "scope.h"
#include "builtin.h"

#ifdef _WIN32
#include "cli_windows.h"
#else
    #include <editline/readline.h>
#endif

int main() {
    init_parser();

    mpc_parser_t *_number  = get_parser_type(NEXP_PARSER_TYPE_NUMBER);
    mpc_parser_t *_symbol  = get_parser_type(NEXP_PARSER_TYPE_SYMBOL);
    mpc_parser_t *_string  = get_parser_type(NEXP_PARSER_TYPE_STRING);
    mpc_parser_t *_comment = get_parser_type(NEXP_PARSER_TYPE_COMMENT);
    mpc_parser_t *_Sexpr   = get_parser_type(NEXP_PARSER_TYPE_SEXPR);
    mpc_parser_t *_Bexpr   = get_parser_type(NEXP_PARSER_TYPE_BEXPR);
    mpc_parser_t *_expr    = get_parser_type(NEXP_PARSER_TYPE_EXPR);

    mpca_lang(MPCA_LANG_DEFAULT,
              "                                                         \
                  number  : /-?[0-9]+/ ;                                \
                  symbol  : /[a-zA-Z0-9_+\\-*\\/\\\\=<>!&:]+/ ;         \
                  string  : /\"(\\\\.|[^\"])*\"/ ;                      \
                  comment : /;[^\\r\\n]*/ ;                             \
                  Sexpr   : '(' <expr>* ')' ;                           \
                  Bexpr   : '{' <expr>* '}' ;                           \
                  expr    : <number> | <symbol> | <string> | <comment>  \
                          | <Sexpr>  | <Bexpr> ;                        \
              ",
              _number, _symbol, _string, _comment, _Sexpr, _Bexpr, _expr);

    puts("Nihilisp REPL v0.1");
    puts("Press Ctrl+C to Exit\n");

    scope_t *scope = scope_new();
    init_builtins(scope);

    while (1) {
        char *input = readline("> ");
        add_history(input);

        mpc_result_t r;

        if (mpc_parse("<stdin>", input, _Sexpr, &r)) {
            nexp_t *result = eval_nexp(scope, parse_expr(r.output));
            nexp_print(result);
            nexp_delete(result);
            mpc_ast_delete(r.output);
        } else {
            mpc_err_print(r.error);
            mpc_err_delete(r.error);
        }

        free(input);
    }

    scope_delete(scope);
    mpc_cleanup(7, _number, _symbol, _string, _comment, _Sexpr, _Bexpr, _expr);

    return 0;
}
