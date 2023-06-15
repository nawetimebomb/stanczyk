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
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "fileman.h"
#include "compiler.h"
#include "chunk.h"
#include "constant.h"
#include "scanner.h"
#include "frontend.h"
#include "memory.h"
#include "object.h"
#include "logger.h"
#include "printer.h"

typedef struct {
    int start;
    int capacity;
    int count;
    Token *tokens;
} TokenArray;

typedef struct {
    int start;
    int capacity;
    int count;
    String **names;
    TokenArray *statements;
} MacroArray;

typedef struct {
    int start;
    int capacity;
    int count;
    String **names;
} Memories;

typedef struct {
    Token current;
    Token previous;
    bool erred;
    bool panic;
} Parser;

typedef void (*ParseFn)(Token);

typedef struct {
    ParseFn     normal;
} ParseRule;

typedef struct {
    int start;
    int capacity;
    int count;
    CFunction **fn;
} CFunctionArray;

typedef struct {
    int start;
    int capacity;
    int count;
    Function **fn;
} FunctionArray;

typedef struct {
    Chunk chunk;
    CFunctionArray cfunctions;
    FunctionArray functions;
} Bytecode;

Compiler *the_compiler;
Memories memories;
MacroArray macros;
Parser parser;
Bytecode *current;

static Chunk *current_chunk() {
    return &current->chunk;
}

static void init_token_array(TokenArray *array) {
    array->start = 16;
    array->count = 0;
    array->capacity = 0;
    array->tokens = NULL;
}

static void init_macros_array() {
    macros.start = 32;
    macros.count = 0;
    macros.capacity = 0;
    macros.names = NULL;
    macros.statements = NULL;
}

static void init_memories_array() {
    memories.start = 8;
    memories.count = 0;
    memories.capacity = 0;
    memories.names = NULL;
}

static void init_cfunction_array(CFunctionArray *array) {
    array->start = 8;
    array->capacity = 0;
    array->count = 0;
    array->fn = NULL;
}

static void init_function_array(FunctionArray *array) {
    array->start = 16;
    array->capacity = 0;
    array->count = 0;
    array->fn = NULL;
}

static void append_clib(ClibArray *array, String *name) {
    if (array->capacity < array->count + 1) {
        int prev_cap = array->capacity;
        array->capacity = GROW_CAPACITY(prev_cap, array->start);
        array->libs = GROW_ARRAY(String *, array->libs, prev_cap, array->capacity);
    }

    array->libs[array->count] = name;
    array->count++;
}

static TokenArray *create_macro(String *name) {
    if (macros.capacity < macros.count + 1) {
        int prev_capacity = macros.capacity;
        macros.capacity = GROW_CAPACITY(prev_capacity, macros.start);
        macros.names = GROW_ARRAY(String *, macros.names,
                                  prev_capacity, macros.capacity);
        macros.statements = GROW_ARRAY(TokenArray, macros.statements,
                                       prev_capacity, macros.capacity);
    }

    TokenArray *result = &macros.statements[macros.count];
    init_token_array(result);

    macros.names[macros.count] = copy_string(name->chars, name->length);
    macros.count++;

    return result;
}

static void append_token(TokenArray *array, Token token) {
    if (array->capacity < array->count + 1) {
        int prev_capacity = array->capacity;
        array->capacity = GROW_CAPACITY(prev_capacity, array->start);
        array->tokens = GROW_ARRAY(Token, array->tokens, prev_capacity, array->capacity);
    }

    array->tokens[array->count] = token;
    array->count++;
}

static void append_memory_name(Memories *array, String *name) {
    if (array->capacity < array->count + 1) {
        int prev_capacity = array->capacity;
        array->capacity = GROW_CAPACITY(prev_capacity, array->start);
        array->names = GROW_ARRAY(String *, array->names, prev_capacity, array->capacity);
    }

    array->names[array->count] = name;
    array->count++;
}

static void append_cfunction(CFunctionArray *array, CFunction *cfunction) {
    if (array->capacity < array->count + 1) {
        int prev_capacity = array->capacity;
        array->capacity = GROW_CAPACITY(prev_capacity, array->start);
        array->fn = GROW_ARRAY(CFunction *, array->fn, prev_capacity, array->capacity);
    }

    array->fn[array->count] = cfunction;
    array->count++;
}

static void append_function(FunctionArray *array, Function *function) {
    if (array->capacity < array->count + 1) {
        int prev_capacity = array->capacity;
        array->capacity = GROW_CAPACITY(prev_capacity, array->start);
        array->fn = GROW_ARRAY(Function *, array->fn, prev_capacity, array->capacity);
    }

    array->fn[array->count] = function;
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

static int find_memory_index(String *query) {
    for (int i = 0; i < memories.count; i++) {
        String *item = memories.names[i];
        if (item->length == query->length &&
            item->hash == query->hash &&
            memcmp(item->chars, query->chars, query->length) == 0) {
            return i;
        }
    }

    return -1;
}

static int find_cfunction_index(String *query) {
    for (int i = 0; i < current->cfunctions.count; i++) {
        String *item = current->cfunctions.fn[i]->name;
        if (item->length == query->length &&
            item->hash == query->hash &&
            memcmp(item->chars, query->chars, query->length) == 0) {
            return i;
        }
    }

    return -1;
}

static int find_function_index(String *query) {
    for (int i = 0; i < current->functions.count; i++) {
        String *item = current->functions.fn[i]->name;
        if (item->length == query->length &&
            item->hash == query->hash &&
            memcmp(item->chars, query->chars, query->length) == 0) {
            return i;
        }
    }

    return -1;
}

static void init_bytecode() {
    current = malloc(sizeof(Bytecode));
    memset(current, 0, sizeof(Bytecode));

    init_chunk(&current->chunk);
    init_macros_array();
    init_memories_array();
    init_cfunction_array(&current->cfunctions);
    init_function_array(&current->functions);
}

/*    ___ ___ ___  ___  ___  ___
 *   | __| _ \ _ \/ _ \| _ \/ __|
 *   | _||   /   / (_) |   /\__ \
 *   |___|_|_\_|_\\___/|_|_\|___/
 */
static void error_at(Token *token, const char *format, ...) {
    if (parser.panic) return;
    parser.panic = true;
    char *message = ALLOCATE(char, 512);
    va_list args;

    va_start(args, format);
    vsprintf(message, format, args);
    va_end(args);
    PARSING_ERROR(token, message);
    parser.erred = true;
    free(message);
}

/*     ___  _   ___  ___ ___ ___
 *    | _ \/_\ | _ \/ __| __| _ \
 *    |  _/ _ \|   /\__ \ _||   /
 *    |_|/_/ \_\_|_\|___/___|_|_\
 */
static void advance() {
    parser.previous = parser.current;

    for (;;) {
        parser.current = scan_token();
        if (parser.current.type != TOKEN_ERROR) break;

        error_at(&parser.current, parser.current.start);
    }
}

static bool consume(TokenType type, const char *message) {
    if (parser.current.type == type) {
        advance();
        return true;
    }

    error_at(&parser.current, message);
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

/*     ___ ___
 *    |_ _| _ \
 *     | ||   /
 *    |___|_|_\
 */
static void emit_byte(u8 byte) {
    write_chunk(current_chunk(), byte, parser.previous.line);
}

static void emit_bytes(u8 b1, u8 b2) {
    emit_byte(b1);
    emit_byte(b2);
}

static u8 make_constant(Value value) {
    int constant = add_constant(current_chunk(), value);
    return (u8)constant;
}

static void emit_constant(u8 op, Value value) {
    emit_bytes(op, make_constant(value));
}

static int emit_jump(u8 instruction) {
    emit_byte(instruction);
    emit_byte(0xff);
    emit_byte(0xff);
    return current_chunk()->count - 2;
}

static void patch_jump(int offset) {
    int jump = current_chunk()->count - offset - 2;

    current_chunk()->code[offset] = (jump >> 8) & 0xff;
    current_chunk()->code[offset + 1] = jump & 0xff;
}

static void emit_loop(int loop_start_ip) {
    emit_byte(OP_LOOP);

    int offset = current_chunk()->count - loop_start_ip + 2;

    emit_byte((offset >> 8) & 0xff);
    emit_byte(offset & 0xff);
}

static void emit_end() {
    emit_byte(OP_END);
}

/*     ___ ___  __  __ ___ ___ _      _ _____ ___ ___  _  _
 *    / __/ _ \|  \/  | _ \_ _| |    /_\_   _|_ _/ _ \| \| |
 *   | (_| (_) | |\/| |  _/| || |__ / _ \| |  | | (_) | .` |
 *    \___\___/|_|  |_|_| |___|____/_/ \_\_| |___\___/|_|\_|
 */
static ParseRule *get_rule(TokenType);
static void parse_next();
static void  parse_this_from(TokenArray *, int);

static void RULE_constant(Token token) {
    switch (token.type) {
        case TOKEN_INT: {
            long value = strtol(token.start, NULL, 10);
            emit_constant(OP_PUSH_INT, INT_VALUE(value));
        } break;
        case TOKEN_STR: {
            emit_constant(OP_PUSH_STR,
                          OBJECT_VALUE(copy_string(token.start + 1, token.length - 2)));
        } break;
        case TOKEN_HEX: {
            emit_constant(OP_PUSH_HEX,
                          OBJECT_VALUE(copy_string(token.start, token.length)));
        } break;
        case TOKEN_FLOAT: {
            double value = strtod(token.start, NULL);
            emit_constant(OP_PUSH_FLOAT, FLOAT_VALUE(value));
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
        case TOKEN_NOT_EQUAL     : emit_byte(OP_NOT_EQUAL);     break;
        case TOKEN_OR            : emit_byte(OP_OR);            break;
        case TOKEN_OVER          : emit_byte(OP_OVER);          break;
        case TOKEN_PRINT         : emit_byte(OP_PRINT);         break;
        case TOKEN_SAVE8         : emit_byte(OP_SAVE8);         break;
        case TOKEN_SWAP          : emit_byte(OP_SWAP);          break;
        case TOKEN_TAKE          : emit_byte(OP_TAKE);          break;
        default: return;
    }
}

static void if_statement() {
    int then_ip, else_ip;

    // Conditionals
    while (!check(TOKEN_DO) && !check(TOKEN_EOF) && !check(TOKEN_ELSE) && !check(TOKEN_DOT)) {
        parse_next();
    }

    consume(TOKEN_DO, "'do' expected after 'if' conditionals\n" "E.g.:\n"
            "\tif 13 31 == do [...] .\n" COLOR_RED"\t            ^^\n"STYLE_OFF
            "All block expressions must be enclosed in 'do' and '.' keywords");

    then_ip = emit_jump(OP_JUMP_IF_FALSE);

    // If is true...
    while (!check(TOKEN_ELSE) && !check(TOKEN_EOF) && !check(TOKEN_DOT)) {
        parse_next();
    }

    else_ip = emit_jump(OP_JUMP);
    patch_jump(then_ip);

    if (match(TOKEN_ELSE)) {
        while (!check(TOKEN_EOF) && !check(TOKEN_DOT)) {
            parse_next();
        }
    }

    patch_jump(else_ip);

    consume(TOKEN_DOT, "'.' (dot) expected after block of code\n" "E.g.:\n"
            "\tif 0 25 < do [...] .\n" COLOR_RED"\t                   ^\n"STYLE_OFF
            "All blocks must end with a '.' (dot)");
}

static void loop_statement() {
    int exit_ip, loop_ip;
    loop_ip = current_chunk()->count;

    // Conditionals
    while (!check(TOKEN_DO) && !check(TOKEN_EOF) && !check(TOKEN_DOT)) {
        parse_next();
    }

    consume(TOKEN_DO, "'do' expected after 'loop' conditionals\n" "E.g.:\n"
            "\tloop 0 25 < do [...] .\n" COLOR_RED"\t            ^^\n"STYLE_OFF
            "All block expressions must be enclosed in 'do' and '.' keywords");

    exit_ip = emit_jump(OP_JUMP_IF_FALSE);

    // Loop body
    while (!check(TOKEN_DOT) && !check(TOKEN_EOF)) {
        parse_next();
    }

    emit_loop(loop_ip);
    patch_jump(exit_ip);

    consume(TOKEN_DOT, "'.' (dot) expected after block of code\n" "E.g.:\n"
            "\tloop 0 25 < do [...] .\n" COLOR_RED "\t                     ^\n"STYLE_OFF
            "All blocks must end with a '.' (dot)");
}

static void static_memory_definition() {
    consume(TOKEN_WORD, "memory definition requires a name after the 'memory' keyword\n"
            "E.g.:" "\tmemory buffer 1024 end\n" COLOR_RED "\t       ^^^^^^\n"STYLE_OFF
            "Memory name may be any word, starting with lowercase or uppercase character,\n"
            "but it may contain numbers, - or _");
    String *word = copy_string(parser.previous.start, parser.previous.length);
    long number = 0;

    if (match(TOKEN_END)) {
        error_at(&parser.previous, "expect Int after the memory name\n"
            "E.g.:\n" "\tmemory buffer 1024 end\n" COLOR_RED "\t              ^^^^\n"STYLE_OFF
            "This number indicates how much memory (in bytes) is going to be saved");
        return;
    }

    if (match(TOKEN_INT)) {
        number = strtol(parser.previous.start, NULL, 10);
    } else if (match(TOKEN_WORD)) {
        int index = find_macro_index(copy_string(parser.previous.start, parser.previous.length));
        Token token = macros.statements[index].tokens[0];
        number = strtol(token.start, NULL, 10);
    }

    emit_byte(OP_DEFINE_PTR);
    emit_bytes(make_constant(OBJECT_VALUE(word)), make_constant(INT_VALUE(number)));
    append_memory_name(&memories, word);

    consume(TOKEN_END,
            "'end' keyword expected after memory definition\n" "E.g.:\n"
            "\tmemory buffer 1024 end\n" COLOR_RED
            "\t                   ^^^\n"STYLE_OFF
            "Memory definition must close with the 'end' keyword");
}

static void RULE_keyword(Token token) {
    switch (token.type) {
        case TOKEN_IF     : if_statement();             break;
        case TOKEN_LOOP   : loop_statement();           break;
        case TOKEN_STATIC : static_memory_definition(); break;
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

static void push_pointer(String *name) {
    emit_constant(OP_PUSH_PTR, OBJECT_VALUE(name));
}

static void call_cfunction(CFunction *fn) {
    emit_bytes(OP_CALL_CFUNC, make_constant(OBJECT_VALUE(fn)));
}

static void call_function(Function *fn) {
    fn->called = true;
    emit_bytes(OP_CALL, make_constant(OBJECT_VALUE(fn)));
}

static void RULE_word(Token token) {
    String *word = copy_string(token.start, token.length);
    int macro_index = find_macro_index(word);
    int memory_index = find_memory_index(word);
    int cfunction_index = find_cfunction_index(word);
    int function_index = find_function_index(word);

    if (macro_index < 0 && memory_index < 0 && cfunction_index < 0 && function_index < 0) {
        error_at(&parser.previous, "unknown word\n" "The word definition has not been found yet in the code\n"
              "Check if the definition is after this line or if you mispelled the word");
        return;
    }

    if (macro_index >= 0)
        { expand_macro(&macros.statements[macro_index]); return; }
    if (memory_index >= 0)
        { push_pointer(memories.names[memory_index]); return; }
    if (cfunction_index >= 0)
        { call_cfunction(current->cfunctions.fn[cfunction_index]); return; }
    if (function_index >= 0)
        { call_function(current->functions.fn[function_index]); return; }
}

static void RULE_skip() {
    // This is for include tokens in main running.
    consume(TOKEN_STR, "file or library name expected after '#include'\n"
            "E.g.:\n" "\t#include \"io\"\n" COLOR_RED "\t         ^^^^\n"STYLE_OFF
            "You can find a list of libraries running skc -help");
    return;
}

static void RULE_ignore() {
    while (!match(TOKEN_END)) advance();
    return;
}

static void RULE_sys(Token token) {
    switch (token.type) {
        case TOKEN___SYS_CALL0  : emit_byte(OP_SYS0);      break;
        case TOKEN___SYS_CALL1  : emit_byte(OP_SYS1);      break;
        case TOKEN___SYS_CALL2  : emit_byte(OP_SYS2);      break;
        case TOKEN___SYS_CALL3  : emit_byte(OP_SYS3);      break;
        case TOKEN___SYS_CALL4  : emit_byte(OP_SYS4);      break;
        case TOKEN___SYS_CALL5  : emit_byte(OP_SYS5);      break;
        case TOKEN___SYS_CALL6  : emit_byte(OP_SYS6);      break;
        case TOKEN___SYS_ADD    : emit_byte(OP_ADD);       break;
        case TOKEN___SYS_DIVMOD : emit_byte(OP_DIVIDE);    break;
        case TOKEN___SYS_MUL    : emit_byte(OP_MULTIPLY);  break;
        case TOKEN___SYS_SUB    : emit_byte(OP_SUBSTRACT); break;
        default: return;
    }
}

ParseRule rules[] = {
    [TOKEN_HASH_INCLUDE]  = {RULE_skip      },
    [TOKEN_HASH_CLIB]     = {RULE_skip      },
    [TOKEN_CONST]         = {RULE_ignore    },
    [TOKEN_MACRO]         = {RULE_ignore    },
    [TOKEN_FUNCTION]      = {RULE_ignore    },
    [TOKEN_C_FUNCTION]    = {RULE_ignore    },

    [TOKEN___SYS_CALL0]   = {RULE_sys       },
    [TOKEN___SYS_CALL1]   = {RULE_sys       },
    [TOKEN___SYS_CALL2]   = {RULE_sys       },
    [TOKEN___SYS_CALL3]   = {RULE_sys       },
    [TOKEN___SYS_CALL4]   = {RULE_sys       },
    [TOKEN___SYS_CALL5]   = {RULE_sys       },
    [TOKEN___SYS_CALL6]   = {RULE_sys       },
    [TOKEN___SYS_ADD]     = {RULE_sys       },
    [TOKEN___SYS_DIVMOD]  = {RULE_sys       },
    [TOKEN___SYS_MUL]     = {RULE_sys       },
    [TOKEN___SYS_SUB]     = {RULE_sys       },

    [TOKEN_INT]           = {RULE_constant  },
    [TOKEN_STR]           = {RULE_constant  },
    [TOKEN_FLOAT]         = {RULE_constant  },
    [TOKEN_HEX]           = {RULE_constant  },

    [TOKEN_IF]            = {RULE_keyword   },
    [TOKEN_LOOP]          = {RULE_keyword   },
    [TOKEN_STATIC]        = {RULE_keyword   },

    [TOKEN_OR]            = {RULE_intrinsic },
    [TOKEN_AND]           = {RULE_intrinsic },
    [TOKEN_DEC]           = {RULE_intrinsic },
    [TOKEN_DROP]          = {RULE_intrinsic },
    [TOKEN_DUP]           = {RULE_intrinsic },
    [TOKEN_EQUAL]         = {RULE_intrinsic },
    [TOKEN_GREATER]       = {RULE_intrinsic },
    [TOKEN_GREATER_EQUAL] = {RULE_intrinsic },
    [TOKEN_INC]           = {RULE_intrinsic },
    [TOKEN_LESS]          = {RULE_intrinsic },
    [TOKEN_LESS_EQUAL]    = {RULE_intrinsic },
    [TOKEN_LOAD8]         = {RULE_intrinsic },
    [TOKEN_NOT_EQUAL]     = {RULE_intrinsic },
    [TOKEN_OVER]          = {RULE_intrinsic },
    [TOKEN_PRINT]         = {RULE_intrinsic },
    [TOKEN_SAVE8]         = {RULE_intrinsic },
    [TOKEN_SWAP]          = {RULE_intrinsic },
    [TOKEN_TAKE]          = {RULE_intrinsic },

    [TOKEN_WORD]          = {RULE_word      },
};

static ParseRule *get_rule(TokenType type) {
    return &rules[type];
}

static void parse_next() {
    advance();
    Token token = parser.previous;
    ParseRule *rule = get_rule(token.type);
    if (rule->normal == NULL) {
        error_at(&parser.previous, "unknown expression");
        return;
    }
    rule->normal(token);
}

static void parse_this_from(TokenArray *statement, int index) {
    Token token = statement->tokens[index];
    ParseRule *rule = get_rule(token.type);

    if (rule->normal == NULL) {
        String *token_name = copy_string(token.start, token.length);
        error_at(&token, "unknown expression while expanding macro\n"
                "Failed to parse '%s' expression."
                "This is most likely a bug in the compiler\n"
                "Please, open a ticket at %s. Thank you!", token_name->chars, GIT_URL);
        return;
    }

    rule->normal(token);
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
            "E.g.:\n" "\t#include \"io\"\n" COLOR_RED "\t         ^^^^\n"STYLE_OFF
            "You can find a list of libraries running skc -help");
    String *name = copy_string(parser.previous.start + 1, parser.previous.length - 2);

    if (library_exists(name->chars)) {
        if (library_not_processed(name->chars)) {
            process_and_save_file(name->chars);
        }
    } else {
        error_at(&parser.previous, "failed to find library to include: %s\n"
                "Make sure the name is correct. If it is an internal Stańczyk library, you\n"
                "must omit the '.sk' in the name. If it is your code, then you must have '.sk'\n"
                "The relative path to your libraries starts from the entry point base path\n"
                "E.g.:\n" "\t#include \"my/code.sk\"\n"
                "This means the file is inside a folder called 'my', adjacent to the entry file",
                name->chars);
    }
}

static void clib_include() {
    consume(TOKEN_STR, "TODO");
    String *libname = copy_string(parser.previous.start + 1, parser.previous.length - 2);
    bool loaded = false;

    for (int i = 0; i < the_compiler->clibs.count; i++) {
        String *item = the_compiler->clibs.libs[i];
        if (libname->length == item->length &&
            libname->hash == item->hash &&
            memcmp(libname->chars, item->chars, libname->length)) {
            loaded = true;
        }
    }

    if (!loaded) {
        append_clib(&the_compiler->clibs, libname);
    }
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
        error_at(&parser.previous, "word %s already in use\n"
                "You cannot override existing declarations in Stańczyk,\n"
                 "must select a different name for this macro", word->chars);
        return;
    }

    consume(TOKEN_SET, "'set' expected after the name of this macro\n" "E.g.:\n"
            "\t:> my-macro set [...] end\n" COLOR_RED
            "\t            ^^^\n"STYLE_OFF
            "Macro declaration statements must be enclosed in 'set' and 'end' keywords");

    if (match(TOKEN_END)) {
        error_at(&parser.previous, "missing macro content after 'set'. Empty macros are not allowed\n" "E.g.:\n"
              "\t:> my-macro set [...] end\n" COLOR_RED
              "\t                ^^^^^\n"STYLE_OFF
              "Macro content may be anything, including other macros, but not the same macro");
        return;
    }

    TokenArray *statement = create_macro(word);

    while (!check(TOKEN_END) && !check(TOKEN_EOF)) {
        advance();
        Token token = parser.previous;
        if (token.type == TOKEN_IF || token.type == TOKEN_LOOP)
            error_at(&token, "if and loop blocks are not allowed in macros\n");
        // TODO: Improve the error message
        append_token(statement, token);
    }

    consume(TOKEN_END,
            "'end' keyword expected after macro declaration\n" "E.g.:\n"
            "\t:> my-macro set [...] end\n" COLOR_RED
            "\t                      ^^^\n"STYLE_OFF
            "Macro declaration must close with the 'end' keyword");
}

static void const_statement() {
    consume(TOKEN_WORD,
            "a valid word is expected after the const definition symbol\n" "E.g.:\n"
            "\t:= my-const <value> end\n" COLOR_RED
            "\t   ^^^^^^^^\n"STYLE_OFF
            "Name may be any word starting with a lowercase or uppercase character, "
            "but it may contain numbers, _ or -");
    String *word = copy_string(parser.previous.start, parser.previous.length);
    int macro_index = find_macro_index(word);

    if (macro_index != -1) {
        error_at(&parser.previous, "word %s already in use\n"
                "You cannot override existing declarations in Stańczyk,\n"
                "must select a different name for this const", word->chars);
        return;
    }

    if (match(TOKEN_END)) {
        error_at(&parser.previous, "missing const content after name. Empty const are not allowed\n" "E.g.:\n"
              "\t:> my-const <value> end\n" COLOR_RED
              "\t            ^^^^^^^\n"STYLE_OFF
              "Const content may be a constant value, like an Int or Str");
        return;
    }

    TokenArray *statement = create_macro(word);
    advance();
    Token token = parser.previous;
    if (token.type == TOKEN_INT || token.type == TOKEN_STR) {
        append_token(statement, token);
    } else {
        error_at(&parser.previous, "you can only assign a constant value to a 'const'\n"
              "Only an Int or Str is allowed to be used here");
    }

    consume(TOKEN_END,
            "'end' keyword expected after const declaration\n" "E.g.:\n"
            "\t:> my-const <value> end\n" COLOR_RED
            "\t                    ^^^\n"STYLE_OFF
            "Const declaration must close with the 'end' keyword");
}

static DataType get_data_type(Token token) {
    switch (token.type) {
        case TOKEN_DATATYPE_INT: return DATA_INT;
        case TOKEN_DATATYPE_STR: return DATA_STR;
        case TOKEN_DATATYPE_BOOL: return DATA_BOOL;
        case TOKEN_DATATYPE_PTR: return DATA_PTR;
        case TOKEN_DATATYPE_FLOAT: return DATA_FLOAT;
        case TOKEN_DATATYPE_HEX: return DATA_HEX;
        default: return DATA_NULL;
    }
}

static void cfunction_statement() {
    consume(TOKEN_WORD, "Name in Stanczyk FIX");
    CFunction *cfunction = new_cfunction();
    cfunction->name = copy_string(parser.previous.start, parser.previous.length);
    consume(TOKEN_WORD, "Name in C FIX");
    cfunction->cname = copy_string(parser.previous.start, parser.previous.length);
    while (!check(TOKEN_RIGHT_ARROW) && !check(TOKEN_EOF) && !check(TOKEN_END)) {
        advance();
        cfunction->arguments[cfunction->arity] = get_data_type(parser.previous);
        cfunction->arity++;
    }

    if (match(TOKEN_RIGHT_ARROW)) {
        advance();
        cfunction->ret = get_data_type(parser.previous);
    }

    consume(TOKEN_END, "end keyword FIX");

    append_cfunction(&current->cfunctions, cfunction);
}

static void function_statement() {
    consume(TOKEN_WORD, "Name in Stanczyk FIX");
    Function *function = new_function();
    function->name = copy_string(parser.previous.start, parser.previous.length);

    while (!check(TOKEN_RIGHT_ARROW) && !check(TOKEN_EOF) && !check(TOKEN_END)) {
        advance();
        function->arguments[function->arity] = get_data_type(parser.previous);
        function->arity++;
    }

    if (match(TOKEN_RIGHT_ARROW)) {
        advance();
        function->ret = get_data_type(parser.previous);
    }

    append_function(&current->functions, function);

    consume(TOKEN_SET, "fix this");

    emit_bytes(OP_DEFINE_FUNCTION, make_constant(OBJECT_VALUE(function)));

    while (!check(TOKEN_END) && !check(TOKEN_EOF)) {
        parse_next();
    }

    emit_byte(OP_RETURN);
    consume(TOKEN_END, "end keyword FIX");
    emit_bytes(OP_FUNCTION_END, make_constant(OBJECT_VALUE(function)));
}

static void run_preprocessor_tokens(int index) {
    const char *filename = get_filename(index);
    const char *source = get_filesource(index);

    init_scanner(filename, source);
    advance();
    while (!match(TOKEN_EOF)) {
        advance();
        switch (parser.previous.type) {
            case TOKEN_HASH_INCLUDE : hash_include();        break;
            case TOKEN_HASH_CLIB    : clib_include();        break;

            case TOKEN_MACRO        : macro_statement();     break;
            case TOKEN_CONST        : const_statement();     break;
            case TOKEN_C_FUNCTION   : cfunction_statement(); break;
            case TOKEN_FUNCTION     : function_statement();  break;
            default: break;
        }
        if (parser.panic) synch();
    }
}

static void run_compilation_tokens(int index) {
    const char *filename = get_filename(index);
    const char *source = get_filesource(index);

    init_scanner(filename, source);
    advance();
    while (!match(TOKEN_EOF)) {
        parse_next();
        if (parser.panic) synch();
    }
}

Chunk *create_intermediate_representation(Compiler *compiler) {
    double START = (double)clock() / CLOCKS_PER_SEC;

    init_bytecode();
    the_compiler = compiler;

    // Save libs/basics.sk
    process_and_save_file("basics");

    // Save the entry file
    process_and_save_file(get_entry_file());

    // Check for #includes, save macros, const and functions
    for (int index = 0; index < get_files_count(); index++) {
        run_preprocessor_tokens(index);
    }

    // Process all the saved files and their source code
    for (int index = 0; index < get_files_count(); index++) {
        run_compilation_tokens(index);
    }

    emit_end();

    current->chunk.erred = parser.erred;

    double END = (double)clock() / CLOCKS_PER_SEC;
    compiler->timers.frontend = END - START;

    stop_filemanager();

    return &current->chunk;
}
