#ifndef STANCZYK_BUILTIN_H
#define STANCZYK_BUILTIN_H 1

#define STACK_MAX_SIZE 32767

#include <stdint.h>
#include <stdio.h>

#define skc_inline  static inline
#define skc_program static

// Stanczyk type definition

typedef int8_t     s8;
typedef int16_t    s16;
typedef int32_t    s32;
typedef int64_t    s64;

typedef uint8_t    u8;
typedef uint16_t   u16;
typedef uint32_t   u32;
typedef uint64_t   u64;

typedef int8_t     b8;
typedef int16_t    b16;
typedef int32_t    b32;
typedef int64_t    b64;

typedef float      f32;
typedef double     f64;

typedef struct {
    const char* data;
    int64_t     len;
} String;

#define b8_false   (b8)  0
#define b16_false  (b16) 0
#define b32_false  (b32) 0
#define b64_false  (b64) 0
#define b8_true    (b8)  0xff
#define b16_true   (b16) 0xffff
#define b32_true   (b32) 0xffffffff
#define b64_true   (b64) 0xffffffffffffffff

typedef union {
    s8     as_s8;
    s16    as_s16;
    s32    as_s32;
    s64    as_s64;

    u8     as_u8;
    u16    as_u16;
    u32    as_u32;
    u64    as_u64;

    b8     as_b8;
    b16    as_b16;
    b32    as_b32;
    b64    as_b64;

    f32    as_f32;
    f64    as_f64;

    String as_string;
} Value;

typedef struct {
    int   top;
    Value values[STACK_MAX_SIZE];
} Skc_Stack;

Skc_Stack stack;

skc_inline b8 stack_is_empty() {
    return stack.top == -1;
}

skc_inline b8 stack_is_full() {
    return stack.top == STACK_MAX_SIZE - 1;
}

skc_inline void stack_push(Value v) {
    stack.values[++stack.top] = v;
}

skc_inline Value stack_pop() {
    Value v = stack.values[stack.top];
    stack.top--;
    return v;
}

skc_inline Value stack_peek() {
    return stack.values[stack.top];
}

skc_inline void push_s8     (s8     v) { stack_push((Value){ .as_s8     = v }); }
skc_inline void push_s16    (s16    v) { stack_push((Value){ .as_s16    = v }); }
skc_inline void push_s32    (s32    v) { stack_push((Value){ .as_s32    = v }); }
skc_inline void push_s64    (s64    v) { stack_push((Value){ .as_s64    = v }); }
skc_inline void push_u8     (u8     v) { stack_push((Value){ .as_u8     = v }); }
skc_inline void push_u16    (u16    v) { stack_push((Value){ .as_u16    = v }); }
skc_inline void push_u32    (u32    v) { stack_push((Value){ .as_u32    = v }); }
skc_inline void push_u64    (u64    v) { stack_push((Value){ .as_u64    = v }); }
skc_inline void push_b8     (b8     v) { stack_push((Value){ .as_b8     = v }); }
skc_inline void push_b16    (b16    v) { stack_push((Value){ .as_b16    = v }); }
skc_inline void push_b32    (b32    v) { stack_push((Value){ .as_b32    = v }); }
skc_inline void push_b64    (b64    v) { stack_push((Value){ .as_b64    = v }); }
skc_inline void push_f32    (f32    v) { stack_push((Value){ .as_f32    = v }); }
skc_inline void push_f64    (f64    v) { stack_push((Value){ .as_f64    = v }); }

skc_inline void push_string (String v) { stack_push((Value){ .as_string = v }); }

skc_inline s8     pop_s8     () { return stack_pop().as_s8;     }
skc_inline s16    pop_s16    () { return stack_pop().as_s16;    }
skc_inline s32    pop_s32    () { return stack_pop().as_s32;    }
skc_inline s64    pop_s64    () { return stack_pop().as_s64;    }
skc_inline u8     pop_u8     () { return stack_pop().as_u8;     }
skc_inline u16    pop_u16    () { return stack_pop().as_u16;    }
skc_inline u32    pop_u32    () { return stack_pop().as_u32;    }
skc_inline u64    pop_u64    () { return stack_pop().as_u64;    }
skc_inline b8     pop_b8     () { return stack_pop().as_b8;     }
skc_inline b16    pop_b16    () { return stack_pop().as_b16;    }
skc_inline b32    pop_b32    () { return stack_pop().as_b32;    }
skc_inline b64    pop_b64    () { return stack_pop().as_b64;    }
skc_inline f32    pop_f32    () { return stack_pop().as_f32;    }
skc_inline f64    pop_f64    () { return stack_pop().as_f64;    }

skc_inline String pop_string () { return stack_pop().as_string; }

// Stanczyk built-in functions

skc_program void print_s8     (s8     v) { printf("%i",   (s32)v);               }
skc_program void print_s16    (s16    v) { printf("%hi",  v);                    }
skc_program void print_s32    (s32    v) { printf("%i",   v);                    }
skc_program void print_s64    (s64    v) { printf("%li",  v);                    }
skc_program void print_u8     (u8     v) { printf("%u",   (u32)v);               }
skc_program void print_u16    (u16    v) { printf("%hu",  v);                    }
skc_program void print_u32    (u32    v) { printf("%u",   v);                    }
skc_program void print_u64    (u64    v) { printf("%lu",  v);                    }
skc_program void print_b8     (b8     v) { printf("%s",   v ? "true" : "false"); }
skc_program void print_b16    (b16    v) { printf("%s",   v ? "true" : "false"); }
skc_program void print_b32    (b32    v) { printf("%s",   v ? "true" : "false"); }
skc_program void print_b64    (b64    v) { printf("%s",   v ? "true" : "false"); }
skc_program void print_f32    (f32    v) { printf("%f",   v);                    }
skc_program void print_f64    (f64    v) { printf("%g",   v);                    }

skc_program void print_string (String v) { printf("%.*s", (int)v.len, v.data);   }

skc_program void println_s8     (s8     v) { printf("%i\n",   (s32)v);               }
skc_program void println_s16    (s16    v) { printf("%hi\n",  v);                    }
skc_program void println_s32    (s32    v) { printf("%i\n",   v);                    }
skc_program void println_s64    (s64    v) { printf("%li\n",  v);                    }
skc_program void println_u8     (u8     v) { printf("%u\n",   (u32)v);               }
skc_program void println_u16    (u16    v) { printf("%hu\n",  v);                    }
skc_program void println_u32    (u32    v) { printf("%u\n",   v);                    }
skc_program void println_u64    (u64    v) { printf("%lu\n",  v);                    }
skc_program void println_b8     (b8     v) { printf("%s\n",   v ? "true" : "false"); }
skc_program void println_b16    (b16    v) { printf("%s\n",   v ? "true" : "false"); }
skc_program void println_b32    (b32    v) { printf("%s\n",   v ? "true" : "false"); }
skc_program void println_b64    (b64    v) { printf("%s\n",   v ? "true" : "false"); }
skc_program void println_f32    (f32    v) { printf("%f\n",   v);                    }
skc_program void println_f64    (f64    v) { printf("%g\n",   v);                    }

skc_program void println_string (String v) { printf("%.*s\n", (int)v.len, v.data);   }

skc_program void stanczyk__main();

int main() {
    // Initialize stack
    stack.top = -1;
    stanczyk__main();
    return 0;
}

#endif // STANCZYK_BUILTIN_H
