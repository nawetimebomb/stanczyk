#define STACK_MAX_SIZE 32767

#include <stdint.h>
#include <stdio.h>

#define skc_inline  static inline
#define skc_program static

// Stanczyk type definition

typedef int64_t s64;
typedef int8_t  bool;
typedef double  f64;

typedef struct {
    const char* data;
    int64_t     len;
} String;

#define bool_false (int8_t) 0
#define bool_true  (int8_t) 1

typedef union {
    bool   as_bool;
    f64    as_float;
    s64    as_int;
    String as_string;
} Value;

typedef struct {
    int   top;
    Value values[STACK_MAX_SIZE];
} Stack;

skc_program Stack stack;

skc_inline bool stack_is_empty() { return stack.top == -1; }
skc_inline bool stack_is_full() { return stack.top == STACK_MAX_SIZE - 1; }
skc_inline void stack_push(Value v) { stack.values[++stack.top] = v; }
skc_inline Value stack_peek() { return stack.values[stack.top]; }
skc_inline Value stack_pop() { Value v = stack.values[stack.top]; stack.top--; return v; }
skc_inline void stack_dup() { Value v = stack_pop(); stack_push(v); stack_push(v); }

skc_program void bool_print(bool v) { printf("%s", v ? "true" : "false"); }
skc_program void bool_println(bool v) { printf("%s\n", v ? "true" : "false"); }
skc_inline bool bool_pop() { return stack_pop().as_bool;   }
skc_inline void bool_push(bool v) { stack_push((Value){ .as_bool = v });   }

skc_program void float_print(f64 v) { printf("%g", v); }
skc_program void float_println(f64 v) { printf("%g\n", v); }
skc_inline f64 float_pop() { return stack_pop().as_float;  }
skc_inline void float_push(f64 v) { stack_push((Value){ .as_float = v }); }
skc_inline void float_sum() { f64 b = pop_float(); f64 a = pop_float(); push_float(a + b); }
skc_inline void float_substract() { f64 b = pop_float(); f64 a = pop_float(); push_float(a - b); }
skc_inline void float_multiply() { f64 b = pop_float(); f64 a = pop_float(); push_float(a * b); }
skc_inline void float_divide() { f64 b = pop_float(); f64 a = pop_float(); push_float(a / b); }

skc_program void int_print(s64 v) { printf("%li", v); }
skc_program void int_println(s64 v) { printf("%li\n", v); }
skc_inline s64 int_pop() { return stack_pop().as_int;    }
skc_inline void int_push(s64 v) { stack_push((Value){ .as_int = v });    }
skc_inline void int_sum() { s64 b = pop_int(); s64 a = pop_int(); push_int(a + b); }
skc_inline void int_substract() { s64 b = pop_int(); s64 a = pop_int(); push_int(a - b); }
skc_inline void int_multiply() { s64 b = pop_int(); s64 a = pop_int(); push_int(a * b); }
skc_inline void int_divide() { s64 b = pop_int(); s64 a = pop_int(); push_int(a / b); }

skc_program void string_print(String v) { printf("%.*s", (int)v.len, v.data); }
skc_program void string_println(String v) { printf("%.*s\n", (int)v.len, v.data); }
skc_inline String string_pop() { return stack_pop().as_string; }
skc_inline void string_push(String v) { stack_push((Value){ .as_string = v }); }

skc_program void stanczyk__main();

int main() {
    // Initialize stack
    stack.top = -1;
    stanczyk__main();
    return 0;
}
