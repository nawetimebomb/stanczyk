/* The Stańczyk Programming Language
 *
 *            ¿«fº"└└-.`└└*∞▄_              ╓▄∞╙╙└└└╙╙*▄▄
 *         J^. ,▄▄▄▄▄▄_      └▀████▄ç    JA▀            └▀v
 *       ,┘ ▄████████████▄¿     ▀██████▄▀└      ╓▄██████▄¿ "▄_
 *      ,─╓██▀└└└╙▀█████████      ▀████╘      ▄████████████_`██▄
 *     ;"▄█└      ,██████████-     ▐█▀      ▄███████▀▀J█████▄▐▀██▄
 *     ▌█▀      _▄█▀▀█████████      █      ▄██████▌▄▀╙     ▀█▐▄,▀██▄
 *    ▐▄▀     A└-▀▌  █████████      ║     J███████▀         ▐▌▌╙█µ▀█▄
 *  A╙└▀█∩   [    █  █████████      ▌     ███████H          J██ç ▀▄╙█_
 * █    ▐▌    ▀▄▄▀  J█████████      H    ████████          █    █  ▀▄▌
 *  ▀▄▄█▀.          █████████▌           ████████          █ç__▄▀ ╓▀└ ╙%_
 *                 ▐█████████      ▐    J████████▌          .└╙   █¿   ,▌
 *                 █████████▀╙╙█▌└▐█╙└██▀▀████████                 ╙▀▀▀▀
 *                ▐██▀┘Å▀▄A └▓█╓▐█▄▄██▄J▀@└▐▄Å▌▀██▌
 *                █▄▌▄█M╨╙└└-           .└└▀**▀█▄,▌
 *                ²▀█▄▄L_                  _J▄▄▄█▀└
 *                     └╙▀▀▀▀▀MMMR████▀▀▀▀▀▀▀└
 *
 *
 * ███████╗████████╗ █████╗ ███╗   ██╗ ██████╗███████╗██╗   ██╗██╗  ██╗
 * ██╔════╝╚══██╔══╝██╔══██╗████╗  ██║██╔════╝╚══███╔╝╚██╗ ██╔╝██║ ██╔╝
 * ███████╗   ██║   ███████║██╔██╗ ██║██║       ███╔╝  ╚████╔╝ █████╔╝
 * ╚════██║   ██║   ██╔══██║██║╚██╗██║██║      ███╔╝    ╚██╔╝  ██╔═██╗
 * ███████║   ██║   ██║  ██║██║ ╚████║╚██████╗███████╗   ██║   ██║  ██╗
 * ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "fileman.h"
#include "compiler.h"
#include "chunk.h"
#include "constant.h"
#include "scanner.h"
#include "bytecode.h"
#include "memory.h"
#include "object.h"
#include "printer.h"

typedef struct {
    int capacity;
    int count;
    Token *tokens;
} TokenArray;

typedef struct {
    int capacity;
    int count;
    String **names;
    TokenArray *statements;
} MacroArray;

typedef struct {
    Token current;
    Token previous;
    bool erred;
    bool panic;
} Parser;

typedef void (*ParseFn)(Token);
typedef void (*ParseExFn)(Token, TokenArray *, int);

typedef struct {
    ParseFn     normal;
    ParseExFn   ex;
} ParseRule;

Compiler *the_compiler;
MacroArray macros;
Parser parser;
Chunk *current;

static void init_token_array(TokenArray *array) {
    array->count = 0;
    array->capacity = 0;
    array->tokens = NULL;
}

static void init_macro_array() {
    macros.count = 0;
    macros.capacity = 0;
    macros.names = NULL;
    macros.statements = NULL;
}

static TokenArray *create_macro(String *name) {
    if (macros.capacity < macros.count + 1) {
        int prev_capacity = macros.capacity;
        macros.capacity = GROW_CAPACITY(prev_capacity);
        macros.names = GROW_ARRAY(String *, macros.names,
                                  prev_capacity, macros.capacity);
        macros.statements = GROW_ARRAY(TokenArray, macros.statements,
                                       prev_capacity, macros.capacity);
    }

    if (macros.count == 0) init_token_array(macros.statements);

    TokenArray *result = &macros.statements[macros.count];

    macros.names[macros.count] = copy_string(name->chars, name->length);
    macros.count++;

    return result;
}

static void append_token(TokenArray *array, Token token) {
    if (array->capacity < array->count + 1) {
        int prev_capacity = array->capacity;
        array->capacity = GROW_CAPACITY(prev_capacity);
        array->tokens = GROW_ARRAY(Token, array->tokens, prev_capacity, array->capacity);
    }

    array->tokens[array->count] = token;
    array->count++;
}

static int find_macro_index(String *query) {
    for (int i = 0; i < macros.count; i++) {
        String *item = macros.names[i];
        if (item->length == query->length &&
            item->hash == query->hash &&
            memcmp(item->chars, query->chars, query->length) == 0) {
            return i;
        }
    }

    return -1;
}

/*
 *    __ __    __
 *   / // /__ / /__  ___ _______
 *  / _  / -_) / _ \/ -_) __(_-<
 * /_//_/\__/_/ .__/\__/_/ /___/
 *         /_/
 * Functions that change the state of the compiler. Move through the
 * parsed code, open/close compiler instances and erroring.
 */
static void error_at(Token *token, const char *message) {
    if (parser.panic) return;
    parser.panic = true;
    // TODO: It should use specific file by context
    fprintf(stderr, "\n%s:%d:%d: " STYLE_UNDERSCORE"ERROR",
            token->filename, token->line, token->column);

    if (token->type == TOKEN_EOF) {
        fprintf(stderr, " at end of file");
    } else if (token->type == TOKEN_ERROR) {
        fprintf(stderr, " while lexing");
    } else {
        fprintf(stderr, " at '%.*s'", token->length, token->start);
    }

    fprintf(stderr, STYLE_OFF": %s\n\n", message);
    parser.erred = true;
}

static void error(const char *message) {
    error_at(&parser.previous, message);
}

static void error_at_current(const char *message) {
    error_at(&parser.current, message);
}

static void advance() {
    parser.previous = parser.current;

    for (;;) {
        parser.current = scan_token();
        if (parser.current.type != TOKEN_ERROR) break;

        error_at_current(parser.current.start);
    }
}

static bool consume(TokenType type, const char *message) {
    if (parser.current.type == type) {
        advance();
        return true;
    }

    error_at_current(message);
    return false;
}

static bool check(TokenType type) {
    return parser.current.type == type;
}

static bool match(TokenType type) {
    if (!check(type)) return false;
    advance();
    return true;
}

static bool check_from(TokenArray *statement, int index, TokenType type) {
    return (statement->tokens[index].type == type);
}

static bool consume_from(TokenArray *statement, int *index,
                         TokenType type, const char *message) {
    Token token = statement->tokens[*index];

    if (token.type == type) {
        *index += 1;
        return true;
    }

    error_at(&token, message);
    return false;
}

static bool match_from(TokenArray *statement, int *index, TokenType type) {
    if (statement->tokens[*index].type != type) return false;
    *index += 1;
    return true;
}

static void emit_byte(u8 byte) {
    write_chunk(current, byte, parser.previous.line);
}

static void emit_bytes(u8 b1, u8 b2) {
    emit_byte(b1);
    emit_byte(b2);
}

static u8 make_constant(Value value) {
    int constant = add_constant(current, value);
    return (u8)constant;
}

static void emit_constant(u8 op, Value value) {
    emit_bytes(op, make_constant(value));
}

static int emit_jump(u8 instruction) {
    emit_byte(instruction);
    emit_byte(0xff);
    emit_byte(0xff);
    return current->count - 2;
}

static void patch_jump(int offset) {
    int jump = current->count - offset - 2;

    current->code[offset] = (jump >> 8) & 0xff;
    current->code[offset + 1] = jump & 0xff;
}

static void emit_loop(int loop_start_ip) {
    emit_byte(OP_LOOP);

    int offset = current->count - loop_start_ip + 2;

    emit_byte((offset >> 8) & 0xff);
    emit_byte(offset & 0xff);
}

static void emit_end() {
    emit_byte(OP_END);
}

/*
 *
 *   _____                _ __     __  _
 *  / ___/__  __ _  ___  (_) /__ _/ /_(_)__  ___
 * / /__/ _ \/  ' \/ _ \/ / / _ `/ __/ / _ \/ _ \
 * \___/\___/_/_/_/ .__/_/_/\_,_/\__/_/\___/_//_/
 *               /_/
 * Functions that compile each expression and statement in the language
 */

static ParseRule *get_rule(TokenType);
static void parse_next();
static void parse_this_from(TokenArray *, int);

static void RULE_constant(Token token) {
    switch (token.type) {
        case TOKEN_INT: {
            long value = strtol(token.start, NULL, 10);
            emit_constant(OP_PUSH_INT, NUMBER_VALUE(value));
        } break;
        case TOKEN_STR: {
            emit_constant(OP_PUSH_STR,
                          OBJECT_VALUE(copy_string(token.start + 1, token.length - 2)));
        } break;
        default: return;
    }

}

static void RULE_intrinsic(Token token) {
    switch (token.type) {
        case TOKEN_AND           : emit_byte(OP_AND);           break;
        case TOKEN_DEC           : emit_byte(OP_DEC);           break;
        case TOKEN_DROP          : emit_byte(OP_DROP);          break;
        case TOKEN_DUP           : emit_byte(OP_DUP);           break;
        case TOKEN_EQUAL         : emit_byte(OP_EQUAL);         break;
        case TOKEN_GREATER       : emit_byte(OP_GREATER);       break;
        case TOKEN_GREATER_EQUAL : emit_byte(OP_GREATER_EQUAL); break;
        case TOKEN_INC           : emit_byte(OP_INC);           break;
        case TOKEN_LESS          : emit_byte(OP_LESS);          break;
        case TOKEN_LESS_EQUAL    : emit_byte(OP_LESS_EQUAL);    break;
        case TOKEN_LOAD8         : emit_byte(OP_LOAD8);         break;
        case TOKEN_MINUS         : emit_byte(OP_SUBSTRACT);     break;
        case TOKEN_NOT_EQUAL     : emit_byte(OP_NOT_EQUAL);     break;
        case TOKEN_OR            : emit_byte(OP_OR);            break;
        case TOKEN_OVER          : emit_byte(OP_OVER);          break;
        case TOKEN_PLUS          : emit_byte(OP_ADD);           break;
        case TOKEN_PRINT         : emit_byte(OP_PRINT);         break;
        case TOKEN_SAVE8         : emit_byte(OP_SAVE8);         break;
        case TOKEN_SLASH         : emit_byte(OP_DIVIDE);        break;
        case TOKEN_STAR          : emit_byte(OP_MULTIPLY);      break;
        case TOKEN_SWAP          : emit_byte(OP_SWAP);          break;
        case TOKEN_SYS4          : emit_byte(OP_SYS4);          break;
        default: return;
    }
}

static void construct_statement_array(TokenArray *statement) {
    init_token_array(statement);

    while (!check(TOKEN_END) && !check(TOKEN_EOF) && !check(TOKEN_DOT)) {
        advance();
        Token token = parser.previous;
        append_token(statement, token);
    }

    consume(TOKEN_DOT, "");
    append_token(statement, parser.previous);
}

static void run_if(TokenArray *statement, int starting_index) {
    int then_ip, else_ip;
    int index = starting_index;

    // Conditionals
    while (!check_from(statement, index, TOKEN_DO) &&
           !check_from(statement, index, TOKEN_EOF) &&
           !check_from(statement, index, TOKEN_ELSE) &&
           !check_from(statement, index, TOKEN_DOT)) {
        parse_this_from(statement, index);
        index++;
    }

    consume_from(statement, &index, TOKEN_DO,
                 "'do' expected after 'if' conditionals\n" "E.g.:\n"
                 "\tif 13 31 == do [...] .\n" COLOR_RED"\t            ^^\n"STYLE_OFF
                 "All block expressions must be enclosed in 'do' and '.' keywords");

    then_ip = emit_jump(OP_JUMP_IF_FALSE);

    // If is true...
    while (!check_from(statement, index, TOKEN_ELSE) &&
           !check_from(statement, index, TOKEN_EOF) &&
           !check_from(statement, index, TOKEN_DOT)) {
        parse_this_from(statement, index);
        index++;
    }

    else_ip = emit_jump(OP_JUMP);
    patch_jump(then_ip);

    if (match_from(statement, &index, TOKEN_ELSE)) {
        while (index < statement->count - 1 &&
               !check_from(statement, index, TOKEN_EOF) &&
               !check_from(statement, index, TOKEN_DOT)) {
            parse_this_from(statement, index);
            index++;
        }
    }

    patch_jump(else_ip);

    consume_from(statement, &index, TOKEN_DOT,
                 "'.' (dot) expected after block of code\n" "E.g.:\n"
                 "\tif 0 25 < do [...] .\n" COLOR_RED"\t                   ^\n"STYLE_OFF
                 "All blocks must end with a '.' (dot)");
}

static void inline_if_statement() {
    TokenArray *statement = malloc(sizeof(TokenArray));
    construct_statement_array(statement);
    run_if(statement, 0);
}

static void run_loop(TokenArray *statement, int starting_index) {
    int exit_ip, loop_ip;
    loop_ip = current->count;
    int index = starting_index;

    // Conditionals
    while (!check_from(statement, index, TOKEN_DO) &&
           !check_from(statement, index, TOKEN_EOF) &&
           !check_from(statement, index, TOKEN_DOT)) {
        parse_this_from(statement, index);
        index++;
    }

    consume_from(statement, &index,
                 TOKEN_DO, "'do' expected after 'loop' conditionals\n" "E.g.:\n"
                 "\tloop 0 25 < do [...] .\n" COLOR_RED"\t            ^^\n"STYLE_OFF
                 "All block expressions must be enclosed in 'do' and '.' keywords");

    exit_ip = emit_jump(OP_JUMP_IF_FALSE);

    // Loop body
    while (!check_from(statement, index, TOKEN_DOT) &&
           !check_from(statement, index, TOKEN_EOF)) {
        parse_this_from(statement, index);
        index++;
    }

    emit_loop(loop_ip);
    patch_jump(exit_ip);

    consume_from(statement, &index, TOKEN_DOT,
                 "'.' (dot) expected after block of code\n" "E.g.:\n"
                 "\tloop 0 25 < do [...] .\n" COLOR_RED
                 "\t                     ^\n"STYLE_OFF
                 "All blocks must end with a '.' (dot)");
}

static void inline_loop_statement() {
    TokenArray *statement = malloc(sizeof(TokenArray));
    construct_statement_array(statement);
    run_loop(statement, 0);
}

static void macro_statement() {
    consume(TOKEN_WORD,
            "a valid word is expected after the macro definition symbol\n" "E.g.:\n"
            "\t:> my-macro set [...] end\n" COLOR_RED
            "\t   ^^^^^^^^\n"STYLE_OFF
            "Name may be any word starting with a lowercase or uppercase character, "
            "but it may contain numbers, _ or -");
    String *word = copy_string(parser.previous.start, parser.previous.length);
    int macro_index = find_macro_index(word);

    if (macro_index != -1) {
        error("cannot override macro\n"
              "A macro with this name already exists. Macros cannot be overriden");
        return;
    }

    consume(TOKEN_SET, "'set' expected after the name of this macro\n" "E.g.:\n"
            "\t:> my-macro set [...] end\n" COLOR_RED
            "\t            ^^^\n"STYLE_OFF
            "All declaration statements must be enclosed in 'set' and 'end' keywords");

    if (match(TOKEN_END)) {
        error("missing macro content after 'do'. Empty macros are not allowed\n" "E.g.:\n"
              "\t:> my-macro set [...] end\n" COLOR_RED
              "\t                ^^^^^\n"STYLE_OFF
              "Macro content may be anything, including other macros, but not the same macro");
        return;
    }

    TokenArray *statement = create_macro(word);

    while (!check(TOKEN_END) && !check(TOKEN_EOF)) {
        advance();
        Token token = parser.previous;
        append_token(statement, token);
    }

    consume(TOKEN_END,
            "'end' keyword expected after macro declaration\n" "E.g.:\n"
            "\t:> my-macro set [...] end\n" COLOR_RED
            "\t                      ^^^\n"STYLE_OFF
            "Macro declaration must close with the 'end' keyword");
}

static void RULE_keyword(Token token) {
    switch (token.type) {
        case TOKEN_IF     : inline_if_statement();   break;
        case TOKEN_LOOP   : inline_loop_statement(); break;
            //case TOKEN_MACRO  : macro_statement();       break;
        case TOKEN_MEMORY : emit_byte(OP_MEMORY);    break;
        default: return;
    }
}

static void RULE_keyword_ex(Token token, TokenArray *statement, int next_index) {
    switch (token.type) {
        case TOKEN_IF   : run_if(statement, next_index);   break;
        case TOKEN_LOOP : run_loop(statement, next_index); break;
        default: return;
    }
}

static void expand_macro(TokenArray *statement) {
    for (int i = 0; i < statement->count; i++) {
        Token token = statement->tokens[i];
        parse_this_from(statement, i);
        if (token.type == TOKEN_LOOP || token.type == TOKEN_IF) {
            while (!check_from(statement, i, TOKEN_DOT)) {
                i++;
            }
        }
    }
}

static void RULE_word(Token token) {
    String *word = copy_string(token.start, token.length);
    int index = find_macro_index(word);

    if (index == -1) {
        error("unknown word\n" "The word definition has not been found yet in the code\n"
              "Check if the definition is after this line or if you mispelled the word");
        return;
    }

    expand_macro(&macros.statements[index]);
}

static void RULE_skip() {
    // This is for include tokens in main running.
    consume(TOKEN_STR, "file or library name expected after '#include'\n"
            "E.g.:\n"
            "\t#include \"io\"" COLOR_RED"\t           ^^^^\n"STYLE_OFF
            "You can find a list of libraries running skc -help");
    return;
}

static void RULE_ignore() {
    while (!match(TOKEN_END)) {
        advance();
    }
    return;
}

ParseRule rules[] = {
    [TOKEN_HASH_INCLUDE]  = {RULE_skip,      NULL},
    [TOKEN_MACRO]         = {RULE_ignore,    NULL},
    [TOKEN_INT]           = {RULE_constant,  NULL},
    [TOKEN_STR]           = {RULE_constant,  NULL},
    [TOKEN_IF]            = {RULE_keyword,   RULE_keyword_ex},
    [TOKEN_LOOP]          = {RULE_keyword,   RULE_keyword_ex},
    [TOKEN_MEMORY]        = {RULE_keyword,   NULL},
    [TOKEN_OR]            = {RULE_intrinsic, NULL},
    [TOKEN_AND]           = {RULE_intrinsic, NULL},
    [TOKEN_DEC]           = {RULE_intrinsic, NULL},
    [TOKEN_DROP]          = {RULE_intrinsic, NULL},
    [TOKEN_DUP]           = {RULE_intrinsic, NULL},
    [TOKEN_EQUAL]         = {RULE_intrinsic, NULL},
    [TOKEN_GREATER]       = {RULE_intrinsic, NULL},
    [TOKEN_GREATER_EQUAL] = {RULE_intrinsic, NULL},
    [TOKEN_INC]           = {RULE_intrinsic, NULL},
    [TOKEN_LESS]          = {RULE_intrinsic, NULL},
    [TOKEN_LESS_EQUAL]    = {RULE_intrinsic, NULL},
    [TOKEN_LOAD8]         = {RULE_intrinsic, NULL},
    [TOKEN_MINUS]         = {RULE_intrinsic, NULL},
    [TOKEN_NOT_EQUAL]     = {RULE_intrinsic, NULL},
    [TOKEN_OVER]          = {RULE_intrinsic, NULL},
    [TOKEN_PLUS]          = {RULE_intrinsic, NULL},
    [TOKEN_PRINT]         = {RULE_intrinsic, NULL},
    [TOKEN_SAVE8]         = {RULE_intrinsic, NULL},
    [TOKEN_SLASH]         = {RULE_intrinsic, NULL},
    [TOKEN_STAR]          = {RULE_intrinsic, NULL},
    [TOKEN_SWAP]          = {RULE_intrinsic, NULL},
    [TOKEN_SYS4]          = {RULE_intrinsic, NULL},
    [TOKEN_WORD]          = {RULE_word,      NULL}
};

static ParseRule *get_rule(TokenType type) {
    return &rules[type];
}

static void parse_next() {
    advance();
    Token token = parser.previous;
    ParseRule *rule = get_rule(token.type);
    if (rule->normal == NULL) {
        error("unknown expression");
        return;
    }
    rule->normal(token);
}

static void parse_this_from(TokenArray *statement, int index) {
    Token token = statement->tokens[index];
    ParseRule *rule = get_rule(token.type);

    if (rule->ex != NULL) {
        rule->ex(token, statement, index + 1);
    } else {
        if (rule->normal == NULL) {
            String *token_name = copy_string(token.start, token.length);
            char *error_message = ALLOCATE(char, 128);
            sprintf(error_message, "unknown expression while expanding macro\n"
                    "Failed to parse '%s' expression. "
                    "This is most likely a bug in the compiler.\n"
                    "Please, open a ticket at %s. Thank you!", token_name->chars, GIT_URL);
            error_at(&token, error_message);
            free(error_message);
            return;
        }
        rule->normal(token);
    }
}


static void synch() {
    parser.panic = false;

    while (parser.current.type != TOKEN_EOF) {
        if (parser.previous.type == TOKEN_DOT) return;
        switch (parser.current.type) {
            case TOKEN_END:
            case TOKEN_ELSE:
            case TOKEN_IF:
            case TOKEN_LOOP:
            case TOKEN_MACRO:
            case TOKEN_PRINT:
            case TOKEN_HASH_INCLUDE:
                return;
            default: break;
        }
        advance();
    }
}

static void hash_include() {
    consume(TOKEN_STR, "file or library name expected after '#include'\n"
            "E.g.:\n" "\t#include \"io\"" COLOR_RED"\t           ^^^^\n"STYLE_OFF
            "You can find a list of libraries running skc -help");
    String *name = copy_string(parser.previous.start, parser.previous.length);

    if (library_exists(the_compiler, name->chars)) {
        if (library_not_processed(the_compiler, name->chars)) {
            process_and_save(the_compiler, name->chars);
        }
    } else {
        char *error_message = ALLOCATE(char, 512);
        sprintf(error_message, "failed to find library to include: %s\n"
                "Make sure the name is correct. If it is an internal Stańczyk library, you\n"
                "must omit the '.sk' in the name. If it is your code, then you must have '.sk'\n"
                "The relative path to your libraries starts from the entry point base path\n"
                "E.g.:\n" "\t#include \"my/code.sk\"\n"
                "This means the file is inside a folder called 'my', adjacent to the entry file",
                name->chars);
        error(error_message);
        free(error_message);
    }
}

static void run_preprocessor_tokens(int index) {
    const char *filename = the_compiler->files.filenames[index];
    const char *source = the_compiler->files.sources[index];

    init_scanner(filename, source);
    advance();
    while (!match(TOKEN_EOF)) {
        advance();
        switch (parser.previous.type) {
            case TOKEN_HASH_INCLUDE : hash_include();     break;
            case TOKEN_MACRO        : macro_statement();  break;
            default: break;
        }
        if (parser.panic) synch();
    }
}

static void run_compilation_tokens(int index) {
    const char *filename = the_compiler->files.filenames[index];
    const char *source = the_compiler->files.sources[index];

    init_scanner(filename, source);
    advance();
    while (!match(TOKEN_EOF)) {
        parse_next();
        if (parser.panic) synch();
    }
}

void bytecode(Compiler *compiler, Chunk *chunk) {
    init_macro_array();
    the_compiler = compiler;
    current = chunk;

    // Save the entry file
    const char *entry = the_compiler->options.entry_file;
    process_and_save(the_compiler, entry);

    // Check for #includes, save macros, const and procedures
    for (int index = 0; index < the_compiler->files.count; index++) {
        run_preprocessor_tokens(index);
    }

    // Process all the saved files and their source code
    for (int index = the_compiler->files.count - 1; index >= 0; index--) {
        run_compilation_tokens(index);
    }

    emit_end();

    chunk->erred = parser.erred;
}
