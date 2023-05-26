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

#include "compiler.h"
#include "chunk.h"
#include "constant.h"
#include "scanner.h"
#include "bytecode.h"
#include "memory.h"
#include "object.h"

typedef struct {
    Token current;
    Token previous;
    bool erred;
    bool panic;
} Parser;

typedef void (*ParseFn)();

typedef struct {
    ParseFn fn;
} ParseRule;

extern CompilerOptions options;
Parser parser;
Chunk *current;

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
    fprintf(stderr, "%s:%d:%d: ERROR", options.entry_file, token->line, token->column);

    if (token->type == TOKEN_EOF) {
        fprintf(stderr, " at end of file");
    } else if (token->type == TOKEN_ERROR) {
        fprintf(stderr, " while lexing");
    } else {
        fprintf(stderr, " at '%.*s'", token->length, token->start);
    }

    fprintf(stderr, ": %s\n", message);
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

static void consume(TokenType type, const char *message) {
    if (parser.current.type == type) {
        advance();
        return;
    }

    error_at_current(message);
}

static bool check(TokenType type) {
    return parser.current.type == type;
}

static bool match(TokenType type) {
    if (!check(type)) return false;
    advance();
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

static void RULE_constant() {
    TokenType constant_type = parser.previous.type;

    switch (constant_type) {
        case TOKEN_INT: {
            long value = strtol(parser.previous.start, NULL, 10);
            emit_constant(OP_PUSH_INT, NUMBER_VALUE(value));
        } break;
        case TOKEN_STR: {
            emit_constant(OP_PUSH_STR,
                          OBJECT_VALUE(copy_string(parser.previous.start + 1,
                                                   parser.previous.length - 2)));
        } break;
        default: return;
    }

}

static void RULE_intrinsic() {
    TokenType op_type = parser.previous.type;

    switch (op_type) {
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

static void if_statement() {
    int then_ip, else_ip;
    while (!check(TOKEN_DO) && !check(TOKEN_EOF)) {
        parse_next();
    }

    consume(TOKEN_DO,
            "'do' expected after 'if' conditionals\n"
            "E.g.:\n\tif 13 31 == do [...] .");

    then_ip = emit_jump(OP_JUMP_IF_FALSE);

    while (!check(TOKEN_DOT) && !check(TOKEN_ELSE) && !check(TOKEN_EOF)) {
        parse_next();
    }

    else_ip = emit_jump(OP_JUMP);
    patch_jump(then_ip);

    if (match(TOKEN_ELSE)) {
        while (!check(TOKEN_DOT) && !check(TOKEN_EOF)) {
            parse_next();
        }
    }

    patch_jump(else_ip);

    consume(TOKEN_DOT,
            "'.' (dot) expected after block of code\n"
            "E.g.:\n\tdo [...] .\n"
            "All blocks should end with a '.' (dot). Those include: if, else and loops");
}

static void loop_statement() {
    int exit_ip, loop_ip;
    loop_ip = current->count;

    while (!check(TOKEN_DO) && !check(TOKEN_EOF)) {
        parse_next();
    }

    consume(TOKEN_DO,
            "'do' expected after 'loop' conditionals\n"
            "E.g.:\n\tloop 0 25 < do [...] .");

    exit_ip = emit_jump(OP_JUMP_IF_FALSE);

    while (!check(TOKEN_DOT) && !check(TOKEN_EOF)) {
        parse_next();
    }

    emit_loop(loop_ip);
    patch_jump(exit_ip);

    consume(TOKEN_DOT,
            "'.' (dot) expected after block of code\n"
            "E.g.:\n\tdo [...] .\n"
            "All blocks should end with a '.' (dot). Those include: if, else and loops");
}

static void RULE_keyword() {
    TokenType op_type = parser.previous.type;

    switch (op_type) {
        case TOKEN_IF     : if_statement();       break;
        case TOKEN_LOOP   : loop_statement();     break;
        case TOKEN_MEMORY : emit_byte(OP_MEMORY); break;
        default: return;
    }
}

ParseRule rules[] = {
    [TOKEN_INT]           = {RULE_constant},
    [TOKEN_STR]           = {RULE_constant},
    [TOKEN_IF]            = {RULE_keyword},
    [TOKEN_LOOP]          = {RULE_keyword},
    [TOKEN_MEMORY]        = {RULE_keyword},
    [TOKEN_OR]            = {RULE_intrinsic},
    [TOKEN_AND]           = {RULE_intrinsic},
    [TOKEN_DEC]           = {RULE_intrinsic},
    [TOKEN_DROP]          = {RULE_intrinsic},
    [TOKEN_DUP]           = {RULE_intrinsic},
    [TOKEN_EQUAL]         = {RULE_intrinsic},
    [TOKEN_GREATER]       = {RULE_intrinsic},
    [TOKEN_GREATER_EQUAL] = {RULE_intrinsic},
    [TOKEN_INC]           = {RULE_intrinsic},
    [TOKEN_LESS]          = {RULE_intrinsic},
    [TOKEN_LESS_EQUAL]    = {RULE_intrinsic},
    [TOKEN_LOAD8]         = {RULE_intrinsic},
    [TOKEN_MINUS]         = {RULE_intrinsic},
    [TOKEN_NOT_EQUAL]     = {RULE_intrinsic},
    [TOKEN_OVER]          = {RULE_intrinsic},
    [TOKEN_PLUS]          = {RULE_intrinsic},
    [TOKEN_PRINT]         = {RULE_intrinsic},
    [TOKEN_SAVE8]         = {RULE_intrinsic},
    [TOKEN_SLASH]         = {RULE_intrinsic},
    [TOKEN_STAR]          = {RULE_intrinsic},
    [TOKEN_SWAP]          = {RULE_intrinsic},
    [TOKEN_SYS4]          = {RULE_intrinsic},
    [TOKEN_DOT]           = {NULL},
    [TOKEN_ERROR]         = {NULL},
    [TOKEN_UNKNOWN]       = {NULL},
    [TOKEN_EOF]           = {NULL}
};

static ParseRule *get_rule(TokenType type) {
    return &rules[type];
}

static void parse_next() {
    advance();
    ParseRule *rule = get_rule(parser.previous.type);
    if (rule->fn == NULL) {
        error("unknown expression");
        return;
    }
    rule->fn();
}

static void synch() {
    if (parser.previous.line != parser.current.line) {
        parser.panic = false;
    }
}

void bytecode(const char *source, Chunk *chunk) {
    init_scanner(source);
    current = chunk;

    advance();
    while (!match(TOKEN_EOF)) {
        parse_next();
        if (parser.panic) synch();
    }

    emit_end();

    chunk->erred = parser.erred;
}
