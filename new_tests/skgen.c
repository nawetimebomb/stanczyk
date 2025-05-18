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
typedef int8_t  bool;
typedef double  f64;

typedef struct {
    char* data;
    int   len;
} String;

#define bool_false (int8_t) 0
#define bool_true  (int8_t) 1

typedef union {
    bool   as_bool;
    f64    as_float;
    s64    as_int;
    String as_string;
} Value;

#define STACK_MAX_SIZE 32767

typedef struct {
    int   top;
    Value values[STACK_MAX_SIZE];
} Stack;

skc_program Stack stack;

#define push(X) _Generic((X), bool: bool_push, float: float_push, int: int_push, struct String: string_push)(X)

skc_inline bool stack_is_empty() { return stack.top == -1; }
skc_inline bool stack_is_full() { return stack.top == STACK_MAX_SIZE - 1; }
skc_inline void stack_push(Value v) { stack.values[++stack.top] = v; }
skc_inline Value stack_peek() { return stack.values[stack.top]; }
skc_inline Value stack_pop() { Value v = stack.values[stack.top]; stack.top--; return v; }
skc_inline void stack_dup() { Value v = stack_pop(); stack_push(v); stack_push(v); }
skc_inline void stack_swap() { Value b = stack_pop(); Value a = stack_pop(); stack_push(b); stack_push(a); }

skc_program void bool_print(bool v) { printf("%s", v ? "true" : "false"); }
skc_program void bool_println(bool v) { printf("%s\n", v ? "true" : "false"); }
skc_inline bool bool_pop() { return stack_pop().as_bool; }
skc_inline void bool_push(bool v) { stack_push((Value){ .as_bool = v }); }

skc_program void float_print(f64 v) { printf("%g", v); }
skc_program void float_println(f64 v) { printf("%g\n", v); }
skc_inline f64 float_pop() { return stack_pop().as_float; }
skc_inline void float_push(f64 v) { stack_push((Value){ .as_float = v }); }
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

skc_program void int_print(s64 v) { printf("%li", v); }
skc_program void int_println(s64 v) { printf("%li\n", v); }
skc_inline s64 int_pop() { return stack_pop().as_int; }
skc_inline void int_push(s64 v) { stack_push((Value){ .as_int = v }); }
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

skc_program void string_print(String v) { printf("%.*s", v.len, v.data); }
skc_program void string_println(String v) { printf("%.*s\n", v.len, v.data); }
skc_inline String string_pop() { return stack_pop().as_string; }
skc_inline void string_push(String v) { stack_push((Value){ .as_string = v }); }
skc_inline void string_concat() {
    String b = string_pop();
    String a = string_pop();
    string_push((String){ .data = strcat(a.data, b.data), .len = a.len + b.len });
}

skc_program void stanczyk__main();

int main() {
    // Initialize stack
    stack.top = -1;
    stanczyk__main();
    return 0;
}

skc_program void stanczyk__ip0();

skc_program void stanczyk__main() {
	stanczyk__ip0();
}

skc_program void stanczyk__ip0() {
	push((String){ .data = "equal", .len = 5 });
	string_println(string_pop());
	push((String){ .data = "2 2 = -> true ", .len = 14 });
	string_print(string_pop());
	push(2);
	push(2);
	int_equal();
	bool_println(bool_pop());
	push((String){ .data = "2 3 = -> false ", .len = 15 });
	string_print(string_pop());
	push(2);
	push(3);
	int_equal();
	bool_println(bool_pop());
	push((String){ .data = "3 2 = -> false ", .len = 15 });
	string_print(string_pop());
	push(3);
	push(2);
	int_equal();
	bool_println(bool_pop());
	push((String){ .data = "-----------", .len = 11 });
	string_println(string_pop());
	push((String){ .data = "not equal", .len = 9 });
	string_println(string_pop());
	push((String){ .data = "2 3 != -> true ", .len = 15 });
	string_print(string_pop());
	push(2);
	push(3);
	int_not_equal();
	bool_println(bool_pop());
	push((String){ .data = "3 2 != -> true ", .len = 15 });
	string_print(string_pop());
	push(3);
	push(2);
	int_not_equal();
	bool_println(bool_pop());
	push((String){ .data = "2 2 != -> false ", .len = 16 });
	string_print(string_pop());
	push(2);
	push(2);
	int_not_equal();
	bool_println(bool_pop());
	push((String){ .data = "-----------", .len = 11 });
	string_println(string_pop());
	push((String){ .data = "less", .len = 4 });
	string_println(string_pop());
	push((String){ .data = "3 2 > -> true ", .len = 14 });
	string_print(string_pop());
	push(3);
	push(2);
	int_greater();
	bool_println(bool_pop());
	push((String){ .data = "2 3 > -> false ", .len = 15 });
	string_print(string_pop());
	push(2);
	push(3);
	int_greater();
	bool_println(bool_pop());
	push((String){ .data = "3 3 > -> false ", .len = 15 });
	string_print(string_pop());
	push(3);
	push(3);
	int_greater();
	bool_println(bool_pop());
	push((String){ .data = "-----------", .len = 11 });
	string_println(string_pop());
	push((String){ .data = "less equal", .len = 10 });
	string_println(string_pop());
	push((String){ .data = "3 3 >= -> true ", .len = 15 });
	string_print(string_pop());
	push(3);
	push(3);
	int_greater_equal();
	bool_println(bool_pop());
	push((String){ .data = "3 2 >= -> true ", .len = 15 });
	string_print(string_pop());
	push(3);
	push(2);
	int_greater_equal();
	bool_println(bool_pop());
	push((String){ .data = "2 3 >= -> false ", .len = 16 });
	string_print(string_pop());
	push(2);
	push(3);
	int_greater_equal();
	bool_println(bool_pop());
	push((String){ .data = "-----------", .len = 11 });
	string_println(string_pop());
	push((String){ .data = "greater", .len = 7 });
	string_println(string_pop());
	push((String){ .data = "2 3 < -> true ", .len = 14 });
	string_print(string_pop());
	push(2);
	push(3);
	int_less();
	bool_println(bool_pop());
	push((String){ .data = "3 2 < -> false ", .len = 15 });
	string_print(string_pop());
	push(3);
	push(2);
	int_less();
	bool_println(bool_pop());
	push((String){ .data = "2 2 < -> false ", .len = 15 });
	string_print(string_pop());
	push(2);
	push(2);
	int_less();
	bool_println(bool_pop());
	push((String){ .data = "-----------", .len = 11 });
	string_println(string_pop());
	push((String){ .data = "greater equal", .len = 13 });
	string_println(string_pop());
	push((String){ .data = "2 2 <= -> true ", .len = 15 });
	string_print(string_pop());
	push(2);
	push(2);
	int_less_equal();
	bool_println(bool_pop());
	push((String){ .data = "2 3 <= -> true ", .len = 15 });
	string_print(string_pop());
	push(2);
	push(3);
	int_less_equal();
	bool_println(bool_pop());
	push((String){ .data = "3 2 <= -> false ", .len = 16 });
	string_print(string_pop());
	push(3);
	push(2);
	int_less_equal();
	bool_println(bool_pop());
}
