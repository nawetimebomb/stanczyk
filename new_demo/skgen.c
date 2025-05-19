/*
  ;;  The Stańczyk Programming Language  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;                                                                      ;
  ;            ¿«fº"└└-.`└└*∞▄_              ╓▄∞╙╙└└└╙╙*▄▄               ;
  ;         J^. ,▄▄▄▄▄▄_      └▀████▄ç    JA▀            └▀v             ;
  ;       ,┘ ▄████████████▄¿     ▀██████▄▀└      ╓▄██████▄¿ "▄_          ;
  ;      ,─╓██▀└└└╙▀█████████      ▀████╘      ▄████████████_`██▄        ;
  ;     ;"▄█└      ,██████████-     ▐█▀      ▄███████▀▀J█████▄▐▀██▄      ;
  ;     ▌█▀      _▄█▀▀█████████      █      ▄██████▌▄▀╙     ▀█▐▄,▀██▄    ;
  ;    ▐▄▀     A└-▀▌  █████████      ║     J███████▀         ▐▌▌╙█µ▀█▄   ;
  ;  A╙└▀█∩   [    █  █████████      ▌     ███████H          J██ç ▀▄╙█_  ;
  ; █    ▐▌    ▀▄▄▀  J█████████      H    ████████          █    █  ▀▄▌  ;
  ;  ▀▄▄█▀.          █████████▌           ████████          █ç__▄▀ ╓▀└╙%_;
  ;                 ▐█████████      ▐    J████████▌          .└╙   █¿  ,▌;
  ;                 █████████▀╙╙█▌└▐█╙└██▀▀████████                 ╙▀▀▀ ;
  ;                ▐██▀┘Å▀▄A └▓█╓▐█▄▄██▄J▀@└▐▄Å▌▀██▌                     ;
  ;                █▄▌▄█M╨╙└└-           .└└▀**▀█▄,▌                     ;
  ;                ²▀█▄▄L_                  _J▄▄▄█▀└                     ;
  ;                     └╙▀▀▀▀▀MMMR████▀▀▀▀▀▀▀└                          ;
  ;                                                                      ;
  ;                                                                      ;
  ; ███████╗████████╗ █████╗ ███╗   ██╗ ██████╗███████╗██╗   ██╗██╗  ██╗ ;
  ; ██╔════╝╚══██╔══╝██╔══██╗████╗  ██║██╔════╝╚══███╔╝╚██╗ ██╔╝██║ ██╔╝ ;
  ; ███████╗   ██║   ███████║██╔██╗ ██║██║       ███╔╝  ╚████╔╝ █████╔╝  ;
  ; ╚════██║   ██║   ██╔══██║██║╚██╗██║██║      ███╔╝    ╚██╔╝  ██╔═██╗  ;
  ; ███████║   ██║   ██║  ██║██║ ╚████║╚██████╗███████╗   ██║   ██║  ██╗ ;
  ; ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ;
  ;                                                                      ;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  The Stańczyk Programming Language  ;; */

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define skc_inline  static inline
#define skc_program static

// Stanczyk type definition

typedef int64_t s64;
typedef int8_t  b8;
typedef double  f64;

typedef struct {
    char* data;
    int   len;
} string;

#define BOOL_FALSE (int8_t) 0
#define BOOL_TRUE  (int8_t) 1

#define _STRING(A, B) (string){ .data = A, .len = B }

typedef union {
    b8   as_bool;
    f64    as_float;
    s64    as_int;
    string as_string;
} Value;

#define STACK_MAX_SIZE 32767

typedef struct {
    int   top;
    Value values[STACK_MAX_SIZE];
} Stack;

skc_program Stack stack;

skc_inline b8 stack_is_empty() { return stack.top == -1; }
skc_inline b8 stack_is_full() { return stack.top == STACK_MAX_SIZE - 1; }
skc_inline void stack_push(Value v) { stack.values[++stack.top] = v; }
skc_inline Value stack_peek() { return stack.values[stack.top]; }
skc_inline Value stack_pop() { Value v = stack.values[stack.top]; stack.top--; return v; }
skc_inline void stack_dup() { Value v = stack_pop(); stack_push(v); stack_push(v); }
skc_inline void stack_swap() { Value b = stack_pop(); Value a = stack_pop(); stack_push(b); stack_push(a); }

skc_inline b8 bool_pop() { return stack_pop().as_bool; }
skc_inline void bool_push(b8 v) { stack_push((Value){ .as_bool = v }); }
skc_program void bool_print() { printf("%s", bool_pop() ? "true" : "false"); }
skc_program void bool_println() { printf("%s\n", bool_pop() ? "true" : "false"); }
skc_inline void bool_and() { bool_push(bool_pop() == BOOL_TRUE && bool_pop() == BOOL_TRUE); }
skc_inline void bool_or() { bool_push(bool_pop() == BOOL_TRUE || bool_pop() == BOOL_TRUE); }

skc_inline f64 float_pop() { return stack_pop().as_float; }
skc_inline void float_push(f64 v) { stack_push((Value){ .as_float = v }); }
skc_program void float_print() { printf("%g", float_pop()); }
skc_program void float_println() { printf("%g\n", float_pop()); }
skc_inline void float_equal() { f64 b = float_pop(); f64 a = float_pop(); bool_push(a == b); }
skc_inline void float_greater() { f64 b = float_pop(); f64 a = float_pop(); bool_push(a > b); }
skc_inline void float_greater_equal() { f64 b = float_pop(); f64 a = float_pop(); bool_push(a >= b); }
skc_inline void float_less() { f64 b = float_pop(); f64 a = float_pop(); bool_push(a < b); }
skc_inline void float_less_equal() { f64 b = float_pop(); f64 a = float_pop(); bool_push(a <= b); }
skc_inline void float_not_equal() { f64 b = float_pop(); f64 a = float_pop(); bool_push(a != b); }
skc_inline void float_sum() { f64 b = float_pop(); f64 a = float_pop(); float_push(a + b); }
skc_inline void float_substract() { f64 b = float_pop(); f64 a = float_pop(); float_push(a - b); }
skc_inline void float_multiply() { f64 b = float_pop(); f64 a = float_pop(); float_push(a * b); }
skc_inline void float_divide() { f64 b = float_pop(); f64 a = float_pop(); float_push(a / b); }

skc_inline s64 int_pop() { return stack_pop().as_int; }
skc_inline void int_push(s64 v) { stack_push((Value){ .as_int = v }); }
skc_program void int_print() { printf("%li", int_pop()); }
skc_program void int_println() { printf("%li\n", int_pop()); }
skc_inline void int_equal() { f64 b = int_pop(); f64 a = int_pop(); bool_push(a == b); }
skc_inline void int_greater() { f64 b = int_pop(); f64 a = int_pop(); bool_push(a > b); }
skc_inline void int_greater_equal() { f64 b = int_pop(); f64 a = int_pop(); bool_push(a >= b); }
skc_inline void int_less() { f64 b = int_pop(); f64 a = int_pop(); bool_push(a < b); }
skc_inline void int_less_equal() { f64 b = int_pop(); f64 a = int_pop(); bool_push(a <= b); }
skc_inline void int_not_equal() { f64 b = int_pop(); f64 a = int_pop(); bool_push(a != b); }
skc_inline void int_sum() { s64 b = int_pop(); s64 a = int_pop(); int_push(a + b); }
skc_inline void int_substract() { s64 b = int_pop(); s64 a = int_pop(); int_push(a - b); }
skc_inline void int_modulo() { s64 b = int_pop(); s64 a = int_pop(); int_push(a % b); }
skc_inline void int_multiply() { s64 b = int_pop(); s64 a = int_pop(); int_push(a * b); }
skc_inline void int_divide() { s64 b = int_pop(); s64 a = int_pop(); int_push(a / b); }

skc_inline string string_pop() { return stack_pop().as_string; }
skc_inline void string_push(string v) { stack_push((Value){ .as_string = v }); }
skc_program void string_print() { string v = string_pop(); printf("%.*s", v.len, v.data); }
skc_program void string_println() { string v = string_pop(); printf("%.*s\n", v.len, v.data); }
skc_inline void string_concat() { string b = string_pop(); string a = string_pop(); string_push((string){ .data = strcat(a.data, b.data), .len = a.len + b.len }); }
skc_inline void string_equal() { string b = string_pop(); string a = string_pop(); bool_push(strcmp(a.data, b.data) ? BOOL_FALSE : BOOL_TRUE); }
skc_inline void string_not_equal() { string b = string_pop(); string a = string_pop(); bool_push(strcmp(a.data, b.data) ? BOOL_TRUE : BOOL_FALSE); }

skc_program void main__stanczyk();

int main() {
    // Initialize stack
    stack.top = -1;
    main__stanczyk();
    return 0;
}



skc_program void main__stanczyk() {
	bool_push(BOOL_TRUE);
	bool_push(BOOL_TRUE);
	bool_and();
	bool_println();
	bool_push(BOOL_TRUE);
	bool_push(BOOL_FALSE);
	bool_and();
	bool_println();
	bool_push(BOOL_FALSE);
	bool_push(BOOL_FALSE);
	bool_and();
	bool_println();
	bool_push(BOOL_TRUE);
	bool_push(BOOL_TRUE);
	bool_or();
	bool_println();
	bool_push(BOOL_TRUE);
	bool_push(BOOL_FALSE);
	bool_or();
	bool_println();
	bool_push(BOOL_FALSE);
	bool_push(BOOL_FALSE);
	bool_or();
	bool_println();
}

