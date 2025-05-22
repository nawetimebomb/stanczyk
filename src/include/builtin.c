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

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SK_INLINE  static inline
#define SK_PROGRAM static

#if defined(__x86_64__) || defined(_M_AMD64) || defined(__aarch64__) || defined(__arm64__) || defined(_M_ARM64) || (defined(__riscv_xlen) && __riscv_xlen == 64) || defined(__s390x__) || (defined(__powerpc64__) && defined(__LITTLE_ENDIAN__)) || defined(__loongarch64)
  #define Stanczyk_64bit_Mode 1
#endif

// Stanczyk type definition
typedef int64_t s64;
typedef int32_t s32;
typedef int16_t s16;
typedef int8_t  s8;

typedef uint64_t u64;
typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t u8;

typedef u8 byte;
typedef u32 rune;

typedef unsigned char* byteptr;
typedef char* charptr;
typedef void* voidptr;

typedef size_t usize;
#ifdef __cplusplus
  typedef ptrdiff_t ssize;
#endif

typedef float f32;
typedef double f64;

typedef struct string string;

typedef s8 b8;
typedef s16 b16;
typedef s32 b32;
typedef s64 b64;

#define bool b8

#ifndef false
  #define false (bool) 0
#endif

#ifndef true
  #define true (bool) 1
#endif

#define __STRLIT0 (string){.buf=(byteptr)(""), .len=0, .is_lit=true}
#define __STRLIT(s) ((string){.buf=(byteptr)("" s), .len=(size(s)-1, .is_lit=true)})
#define __STRLEN(s, n) ((string){.buf=(byteptr)("" s), .len=n, .is_lit=true})

struct string {
    byteptr buf;
    int len;
    bool is_lit;
};

// Stanczyk stack
#define STACK_MAX_SIZE 255
typedef enum SKTYPE SKTYPE;
typedef union SKVALUE SKVALUE;
typedef struct Stack_value Stack_value;
typedef struct Program_stack Program_stack;

enum SKTYPE {
    SK_any,

    SK_bool,
    SK_f64,
    SK_f32,
    SK_s64,
    SK_s32,
    SK_s16,
    SK_s8,
    SK_u64,
    SK_u32,
    SK_u16,
    SK_u8,

    SK_quotation,
    SK_string,
};

union SKVALUE {
    bool _bool;

    f32 _f32;
    f64 _f64;

    s64 _s64;
    s32 _s32;
    s16 _s16;
    s8 _s8;

    u64 _u64;
    u32 _u32;
    u16 _u16;
    u8 _u8;

    char* _quotation;
    string _string;
};

struct Stack_value {
    SKTYPE t;
    SKVALUE v;
};

struct Program_stack {
    int top;
    Stack_value values[STACK_MAX_SIZE];
};

SK_PROGRAM Program_stack the_stack;

SK_INLINE bool _builtin__stack_is_empty();
SK_INLINE bool _builtin__stack_is_full();
SK_INLINE Stack_value _builtin__stack_peek();
SK_INLINE Stack_value _builtin__pop();
SK_INLINE void _builtin__push(SKTYPE t, SKVALUE v);
SK_INLINE void _builtin__swap();
SK_INLINE void _builtin__dup();

SK_INLINE bool _builtin__stack_is_empty() {
    return the_stack.top <= 0;
}

SK_INLINE bool _builtin__stack_is_full() {
    return the_stack.top == STACK_MAX_SIZE - 1;
}

SK_INLINE void _builtin__push(SKTYPE t, SKVALUE v) {
    the_stack.values[++the_stack.top] = (Stack_value){.t = t, .v = v};
}

SK_INLINE Stack_value _builtin__stack_peek() {
    return the_stack.values[the_stack.top];
}

SK_INLINE Stack_value _builtin__pop() {
    Stack_value a = the_stack.values[the_stack.top];
    the_stack.top--;
    return a;
}

SK_INLINE void _builtin__dup() {
    Stack_value a = _builtin__pop();
    _builtin__push(a.t, a.v);
    _builtin__push(a.t, a.v);
}

SK_INLINE void _builtin__swap() {
    Stack_value b = _builtin__pop();
    Stack_value a = _builtin__pop();
    _builtin__push(b.t, b.v);
    _builtin__push(a.t, b.v);
}

SK_PROGRAM void _builtin__print() {
    Stack_value a = _builtin__pop();

    switch (a.t) {
        case SK_bool: printf("%s", a.v._bool ? "true" : "false"); break;
        case SK_f64: printf("%g", a.v._f64); break;
        case SK_f32: printf("%f", a.v._f32); break;
        case SK_s64: printf("%li", a.v._s64); break;
        case SK_s32: printf("%i", a.v._s32); break;
        case SK_s16: printf("%hi", a.v._s16); break;
        case SK_s8: printf("%i", (s32)a.v._s8); break;
        case SK_u64: printf("%lu", a.v._u64); break;
        case SK_u32: printf("%u", a.v._u32); break;
        case SK_u16: printf("%hu", a.v._u16); break;
        case SK_u8: printf("%u", (s32)a.v._u8); break;
        case SK_quotation: printf("%s", a.v._quotation); break;
        case SK_string: {
            string s = a.v._string;
            printf("%.*s", s.len, s.buf);
            if (!s.is_lit) free(s.buf);
        } break;
        default: assert(false);
    }
}

SK_PROGRAM void _builtin__println() {
    _builtin__print();
    printf("\n");
}

SK_INLINE void _builtin__plus() {
    Stack_value b = _builtin__pop();
    Stack_value a = _builtin__pop();
    Stack_value r = {};
    r.t = a.t;

    switch (a.t) {
        case SK_f64: r.v._f64 = a.v._f64 + b.v._f64; break;
        case SK_f32: r.v._f32 = a.v._f32 + b.v._f32; break;
        case SK_s64: r.v._s64 = a.v._s64 + b.v._s64; break;
        case SK_s32: r.v._s32 = a.v._s32 + b.v._s32; break;
        case SK_s16: r.v._s16 = a.v._s16 + b.v._s16; break;
        case SK_s8: r.v._s8 = a.v._s8 + b.v._s8; break;
        case SK_u64: r.v._u64 = a.v._u64 + b.v._u64; break;
        case SK_u32: r.v._u32 = a.v._u32 + b.v._u32; break;
        case SK_u16: r.v._u16 = a.v._u16 + b.v._u16; break;
        case SK_u8: r.v._u8 = a.v._u8 + b.v._u8; break;
        case SK_string: {
            string s1 = a.v._string;
            string s2 = b.v._string;
            int new_len = s1.len + s2.len;
            byteptr new_str = (byteptr)malloc(sizeof(byte) * new_len);
            { // Unsafe
                memcpy(new_str, s1.buf, s1.len);
                memcpy(new_str + s1.len, s2.buf, s2.len);
                new_str[new_len] = 0;
            }
            r.v._string = (string){.buf = new_str, .len = new_len};
        } break;
        default: assert(false);
    }

    _builtin__push(r.t, r.v);
}

SK_INLINE void _builtin__minus() {
    Stack_value b = _builtin__pop();
    Stack_value a = _builtin__pop();
    Stack_value r = {};
    r.t = a.t;

    switch (a.t) {
        case SK_f64: r.v._f64 = a.v._f64 - b.v._f64; break;
        case SK_f32: r.v._f32 = a.v._f32 - b.v._f32; break;
        case SK_s64: r.v._s64 = a.v._s64 - b.v._s64; break;
        case SK_s32: r.v._s32 = a.v._s32 - b.v._s32; break;
        case SK_s16: r.v._s16 = a.v._s16 - b.v._s16; break;
        case SK_s8: r.v._s8 = a.v._s8 - b.v._s8; break;
        case SK_u64: r.v._u64 = a.v._u64 - b.v._u64; break;
        case SK_u32: r.v._u32 = a.v._u32 - b.v._u32; break;
        case SK_u16: r.v._u16 = a.v._u16 - b.v._u16; break;
        case SK_u8: r.v._u8 = a.v._u8 - b.v._u8; break;
        default: assert(false);
    }

    _builtin__push(r.t, r.v);
}

SK_INLINE void _builtin__modulo() {
    Stack_value b = _builtin__pop();
    Stack_value a = _builtin__pop();
    Stack_value r = {};
    r.t = a.t;

    switch (a.t) {
        case SK_s64: r.v._s64 = a.v._s64 % b.v._s64; break;
        case SK_s32: r.v._s32 = a.v._s32 % b.v._s32; break;
        case SK_s16: r.v._s16 = a.v._s16 % b.v._s16; break;
        case SK_s8: r.v._s8 = a.v._s8 % b.v._s8; break;
        case SK_u64: r.v._u64 = a.v._u64 % b.v._u64; break;
        case SK_u32: r.v._u32 = a.v._u32 % b.v._u32; break;
        case SK_u16: r.v._u16 = a.v._u16 % b.v._u16; break;
        case SK_u8: r.v._u8 = a.v._u8 % b.v._u8; break;
        default: assert(false);
    }

    _builtin__push(r.t, r.v);
}

SK_INLINE void _builtin__multiply() {
    Stack_value b = _builtin__pop();
    Stack_value a = _builtin__pop();
    Stack_value r = {};
    r.t = a.t;

    switch (a.t) {
        case SK_f64: r.v._f64 = a.v._f64 * b.v._f64; break;
        case SK_f32: r.v._f32 = a.v._f32 * b.v._f32; break;
        case SK_s64: r.v._s64 = a.v._s64 * b.v._s64; break;
        case SK_s32: r.v._s32 = a.v._s32 * b.v._s32; break;
        case SK_s16: r.v._s16 = a.v._s16 * b.v._s16; break;
        case SK_s8: r.v._s8 = a.v._s8 * b.v._s8; break;
        case SK_u64: r.v._u64 = a.v._u64 * b.v._u64; break;
        case SK_u32: r.v._u32 = a.v._u32 * b.v._u32; break;
        case SK_u16: r.v._u16 = a.v._u16 * b.v._u16; break;
        case SK_u8: r.v._u8 = a.v._u8 * b.v._u8; break;
        default: assert(false);
    }

    _builtin__push(r.t, r.v);
}

SK_INLINE void _builtin__divide() {
    Stack_value b = _builtin__pop();
    Stack_value a = _builtin__pop();
    Stack_value r = {};
    r.t = a.t;

    switch (a.t) {
        case SK_f64: r.v._f64 = a.v._f64 / b.v._f64; break;
        case SK_f32: r.v._f32 = a.v._f32 / b.v._f32; break;
        case SK_s64: r.v._s64 = a.v._s64 / b.v._s64; break;
        case SK_s32: r.v._s32 = a.v._s32 / b.v._s32; break;
        case SK_s16: r.v._s16 = a.v._s16 / b.v._s16; break;
        case SK_s8: r.v._s8 = a.v._s8 / b.v._s8; break;
        case SK_u64: r.v._u64 = a.v._u64 / b.v._u64; break;
        case SK_u32: r.v._u32 = a.v._u32 / b.v._u32; break;
        case SK_u16: r.v._u16 = a.v._u16 / b.v._u16; break;
        case SK_u8: r.v._u8 = a.v._u8 / b.v._u8; break;
        default: assert(false);
    }

    _builtin__push(r.t, r.v);
}

SK_INLINE SKVALUE f64_to_(f64 v, SKTYPE to) {
    switch (to) {
        case SK_bool: return (SKVALUE){._bool = v > 0.0f ? true : false};
        case SK_f64: return (SKVALUE){._f64 = (f64)v};
        case SK_f32: return (SKVALUE){._f32 = (f32)v};
        case SK_s64: return (SKVALUE){._s64 = (s64)v};
        case SK_s32: return (SKVALUE){._s32 = (s32)v};
        case SK_s16: return (SKVALUE){._s16 = (s16)v};
        case SK_s8: return (SKVALUE){._s8 = (s8)v};
        case SK_u64: return (SKVALUE){._u64 = (u64)v};
        case SK_u32: return (SKVALUE){._u32 = (u32)v};
        case SK_u16: return (SKVALUE){._u16 = (u16)v};
        case SK_u8: return (SKVALUE){._u8 = (u8)v};
        default: assert(false);
    }
    assert(false);
    return (SKVALUE){._f64 = v};
}

SK_INLINE SKVALUE f32_to_(f32 v, SKTYPE to) {
    switch (to) {
        case SK_bool: return (SKVALUE){._bool = v > 0.0f ? true : false};
        case SK_f64: return (SKVALUE){._f64 = (f64)v};
        case SK_f32: return (SKVALUE){._f32 = (f32)v};
        case SK_s64: return (SKVALUE){._s64 = (s64)v};
        case SK_s32: return (SKVALUE){._s32 = (s32)v};
        case SK_s16: return (SKVALUE){._s16 = (s16)v};
        case SK_s8: return (SKVALUE){._s8 = (s8)v};
        case SK_u64: return (SKVALUE){._u64 = (u64)v};
        case SK_u32: return (SKVALUE){._u32 = (u32)v};
        case SK_u16: return (SKVALUE){._u16 = (u16)v};
        case SK_u8: return (SKVALUE){._u8 = (u8)v};
        default: assert(false);
    }
    assert(false);
    return (SKVALUE){._f32 = v};
}

SK_INLINE SKVALUE s64_to_(s64 v, SKTYPE to) {
    switch (to) {
        case SK_bool: return (SKVALUE){._bool = v > 0 ? true : false};
        case SK_f64: return (SKVALUE){._f64 = (f64)v};
        case SK_f32: return (SKVALUE){._f32 = (f32)v};
        case SK_s64: return (SKVALUE){._s64 = (s64)v};
        case SK_s32: return (SKVALUE){._s32 = (s32)v};
        case SK_s16: return (SKVALUE){._s16 = (s16)v};
        case SK_s8: return (SKVALUE){._s8 = (s8)v};
        case SK_u64: return (SKVALUE){._u64 = (u64)v};
        case SK_u32: return (SKVALUE){._u32 = (u32)v};
        case SK_u16: return (SKVALUE){._u16 = (u16)v};
        case SK_u8: return (SKVALUE){._u8 = (u8)v};
        default: assert(false);
    }
    assert(false);
    return (SKVALUE){._s64 = v};
}

SK_INLINE SKVALUE s32_to_(s32 v, SKTYPE to) {
    switch (to) {
        case SK_bool: return (SKVALUE){._bool = v > 0 ? true : false};
        case SK_f64: return (SKVALUE){._f64 = (f64)v};
        case SK_f32: return (SKVALUE){._f32 = (f32)v};
        case SK_s64: return (SKVALUE){._s64 = (s64)v};
        case SK_s32: return (SKVALUE){._s32 = (s32)v};
        case SK_s16: return (SKVALUE){._s16 = (s16)v};
        case SK_s8: return (SKVALUE){._s8 = (s8)v};
        case SK_u64: return (SKVALUE){._u64 = (u64)v};
        case SK_u32: return (SKVALUE){._u32 = (u32)v};
        case SK_u16: return (SKVALUE){._u16 = (u16)v};
        case SK_u8: return (SKVALUE){._u8 = (u8)v};
        default: assert(false);
    }
    assert(false);
    return (SKVALUE){._s32 = v};
}

SK_INLINE SKVALUE s16_to_(s16 v, SKTYPE to) {
    switch (to) {
        case SK_bool: return (SKVALUE){._bool = v > 0 ? true : false};
        case SK_f64: return (SKVALUE){._f64 = (f64)v};
        case SK_f32: return (SKVALUE){._f32 = (f32)v};
        case SK_s64: return (SKVALUE){._s64 = (s64)v};
        case SK_s32: return (SKVALUE){._s32 = (s32)v};
        case SK_s16: return (SKVALUE){._s16 = (s16)v};
        case SK_s8: return (SKVALUE){._s8 = (s8)v};
        case SK_u64: return (SKVALUE){._u64 = (u64)v};
        case SK_u32: return (SKVALUE){._u32 = (u32)v};
        case SK_u16: return (SKVALUE){._u16 = (u16)v};
        case SK_u8: return (SKVALUE){._u8 = (u8)v};
        default: assert(false);
    }
    assert(false);
    return (SKVALUE){._s16 = v};
}

SK_INLINE SKVALUE s8_to_(s8 v, SKTYPE to) {
    switch (to) {
        case SK_bool: return (SKVALUE){._bool = v > 0 ? true : false};
        case SK_f64: return (SKVALUE){._f64 = (f64)v};
        case SK_f32: return (SKVALUE){._f32 = (f32)v};
        case SK_s64: return (SKVALUE){._s64 = (s64)v};
        case SK_s32: return (SKVALUE){._s32 = (s32)v};
        case SK_s16: return (SKVALUE){._s16 = (s16)v};
        case SK_s8: return (SKVALUE){._s8 = (s8)v};
        case SK_u64: return (SKVALUE){._u64 = (u64)v};
        case SK_u32: return (SKVALUE){._u32 = (u32)v};
        case SK_u16: return (SKVALUE){._u16 = (u16)v};
        case SK_u8: return (SKVALUE){._u8 = (u8)v};
        default: assert(false);
    }
    assert(false);
    return (SKVALUE){._s8 = v};
}

SK_INLINE SKVALUE u64_to_(u64 v, SKTYPE to) {
    switch (to) {
        case SK_bool: return (SKVALUE){._bool = v > 0 ? true : false};
        case SK_f64: return (SKVALUE){._f64 = (f64)v};
        case SK_f32: return (SKVALUE){._f32 = (f32)v};
        case SK_s64: return (SKVALUE){._s64 = (s64)v};
        case SK_s32: return (SKVALUE){._s32 = (s32)v};
        case SK_s16: return (SKVALUE){._s16 = (s16)v};
        case SK_s8: return (SKVALUE){._s8 = (s8)v};
        case SK_u64: return (SKVALUE){._u64 = (u64)v};
        case SK_u32: return (SKVALUE){._u32 = (u32)v};
        case SK_u16: return (SKVALUE){._u16 = (u16)v};
        case SK_u8: return (SKVALUE){._u8 = (u8)v};
        default: assert(false);
    }
    assert(false);
    return (SKVALUE){._u64 = v};
}

SK_INLINE SKVALUE u32_to_(u32 v, SKTYPE to) {
    switch (to) {
        case SK_bool: return (SKVALUE){._bool = v > 0 ? true : false};
        case SK_f64: return (SKVALUE){._f64 = (f64)v};
        case SK_f32: return (SKVALUE){._f32 = (f32)v};
        case SK_s64: return (SKVALUE){._s64 = (s64)v};
        case SK_s32: return (SKVALUE){._s32 = (s32)v};
        case SK_s16: return (SKVALUE){._s16 = (s16)v};
        case SK_s8: return (SKVALUE){._s8 = (s8)v};
        case SK_u64: return (SKVALUE){._u64 = (u64)v};
        case SK_u32: return (SKVALUE){._u32 = (u32)v};
        case SK_u16: return (SKVALUE){._u16 = (u16)v};
        case SK_u8: return (SKVALUE){._u8 = (u8)v};
        default: assert(false);
    }
    assert(false);
    return (SKVALUE){._u32 = v};
}

SK_INLINE SKVALUE u16_to_(u16 v, SKTYPE to) {
    switch (to) {
        case SK_bool: return (SKVALUE){._bool = v > 0 ? true : false};
        case SK_f64: return (SKVALUE){._f64 = (f64)v};
        case SK_f32: return (SKVALUE){._f32 = (f32)v};
        case SK_s64: return (SKVALUE){._s64 = (s64)v};
        case SK_s32: return (SKVALUE){._s32 = (s32)v};
        case SK_s16: return (SKVALUE){._s16 = (s16)v};
        case SK_s8: return (SKVALUE){._s8 = (s8)v};
        case SK_u64: return (SKVALUE){._u64 = (u64)v};
        case SK_u32: return (SKVALUE){._u32 = (u32)v};
        case SK_u16: return (SKVALUE){._u16 = (u16)v};
        case SK_u8: return (SKVALUE){._u8 = (u8)v};
        default: assert(false);
    }
    assert(false);
    return (SKVALUE){._u16 = v};
}

SK_INLINE SKVALUE u8_to_(u8 v, SKTYPE to) {
    switch (to) {
        case SK_bool: return (SKVALUE){._bool = v > 0 ? true : false};
        case SK_f64: return (SKVALUE){._f64 = (f64)v};
        case SK_f32: return (SKVALUE){._f32 = (f32)v};
        case SK_s64: return (SKVALUE){._s64 = (s64)v};
        case SK_s32: return (SKVALUE){._s32 = (s32)v};
        case SK_s16: return (SKVALUE){._s16 = (s16)v};
        case SK_s8: return (SKVALUE){._s8 = (s8)v};
        case SK_u64: return (SKVALUE){._u64 = (u64)v};
        case SK_u32: return (SKVALUE){._u32 = (u32)v};
        case SK_u16: return (SKVALUE){._u16 = (u16)v};
        case SK_u8: return (SKVALUE){._u8 = (u8)v};
        default: assert(false);
    }
    assert(false);
    return (SKVALUE){._u8 = v};
}

SK_INLINE SKVALUE string_to_(string v, SKTYPE to) {
    switch (to) {
        case SK_bool: return (SKVALUE){._bool = v.len > 0 ? true : false};
        default: assert(false);
    }
    assert(false);
    return (SKVALUE){._string = v};
}

SK_INLINE void _builtin__cast(SKTYPE to) {
    Stack_value a = _builtin__pop();
    Stack_value r = {};
    r.t = to;
    SKTYPE from = a.t;

    switch (from) {
        case SK_f64: r.v = f64_to_(a.v._f64, to); break;
        case SK_f32: r.v = f32_to_(a.v._f32, to); break;
        case SK_s64: r.v = s64_to_(a.v._s64, to); break;
        case SK_s32: r.v = s32_to_(a.v._s32, to); break;
        case SK_s16: r.v = s16_to_(a.v._s16, to); break;
        case SK_s8: r.v = s8_to_(a.v._s8, to); break;
        case SK_u64: r.v = u64_to_(a.v._u64, to); break;
        case SK_u32: r.v = u32_to_(a.v._u32, to); break;
        case SK_u16: r.v = u16_to_(a.v._u16, to); break;
        case SK_u8: r.v = u8_to_(a.v._u8, to); break;
        case SK_string: r.v = string_to_(a.v._string, to); break;
        default: assert(false);
    }

    _builtin__push(r.t, r.v);
}

SK_INLINE void _builtin__and() {
    Stack_value b = _builtin__pop();
    Stack_value a = _builtin__pop();
    Stack_value r = {};
    r.t = SK_bool;
    r.v._bool = a.v._bool && b.v._bool;
    _builtin__push(a.t, r.v);
}

SK_INLINE void _builtin__or() {
    Stack_value b = _builtin__pop();
    Stack_value a = _builtin__pop();
    Stack_value r = {};
    r.t = SK_bool;
    r.v._bool = a.v._bool || b.v._bool;
    _builtin__push(a.t, r.v);
}

SK_INLINE void _builtin__eq() {
    Stack_value b = _builtin__pop();
    Stack_value a = _builtin__pop();
    bool r;
    switch (a.t) {
        case SK_bool: r = a.v._bool == b.v._bool; break;
        case SK_f64: r = a.v._f64 == b.v._f64; break;
        case SK_f32: r = a.v._f32 == b.v._f32; break;
        case SK_s64: r = a.v._s64 == b.v._s64; break;
        case SK_s32: r = a.v._s32 == b.v._s32; break;
        case SK_s16: r = a.v._s16 == b.v._s16; break;
        case SK_s8: r = a.v._s8 == b.v._s8; break;
        case SK_u64: r = a.v._u64 == b.v._u64; break;
        case SK_u32: r = a.v._u32 == b.v._u32; break;
        case SK_u16: r = a.v._u16 == b.v._u16; break;
        case SK_u8: r = a.v._u8 == b.v._u8; break;
        case SK_string: {
            string s1 = a.v._string;
            string s2 = b.v._string;
            r = s1.len == s2.len && memcmp(s1.buf, s2.buf, s1.len) == 0;
        } break;
        default: assert(false);
    }
    _builtin__push(SK_bool, (SKVALUE){._bool = r});
}

SK_INLINE void _builtin__ne() {
    Stack_value b = _builtin__pop();
    Stack_value a = _builtin__pop();
    bool r;
    switch (a.t) {
        case SK_bool: r = a.v._bool != b.v._bool; break;
        case SK_f64: r = a.v._f64 != b.v._f64; break;
        case SK_f32: r = a.v._f32 != b.v._f32; break;
        case SK_s64: r = a.v._s64 != b.v._s64; break;
        case SK_s32: r = a.v._s32 != b.v._s32; break;
        case SK_s16: r = a.v._s16 != b.v._s16; break;
        case SK_s8: r = a.v._s8 != b.v._s8; break;
        case SK_u64: r = a.v._u64 != b.v._u64; break;
        case SK_u32: r = a.v._u32 != b.v._u32; break;
        case SK_u16: r = a.v._u16 != b.v._u16; break;
        case SK_u8: r = a.v._u8 != b.v._u8; break;
        case SK_string: {
            string s1 = a.v._string;
            string s2 = b.v._string;
            r = s1.len != s2.len || memcmp(s1.buf, s2.buf, s1.len) != 0;
        } break;
        default: assert(false);
    }
    _builtin__push(SK_bool, (SKVALUE){._bool = r});
}

SK_INLINE void _builtin__gt() {
    Stack_value b = _builtin__pop();
    Stack_value a = _builtin__pop();
    bool r;
    switch (a.t) {
        case SK_bool: r = a.v._bool > b.v._bool; break;
        case SK_f64: r = a.v._f64 > b.v._f64; break;
        case SK_f32: r = a.v._f32 > b.v._f32; break;
        case SK_s64: r = a.v._s64 > b.v._s64; break;
        case SK_s32: r = a.v._s32 > b.v._s32; break;
        case SK_s16: r = a.v._s16 > b.v._s16; break;
        case SK_s8: r = a.v._s8 > b.v._s8; break;
        case SK_u64: r = a.v._u64 > b.v._u64; break;
        case SK_u32: r = a.v._u32 > b.v._u32; break;
        case SK_u16: r = a.v._u16 > b.v._u16; break;
        case SK_u8: r = a.v._u8 > b.v._u8; break;
        default: assert(false);
    }
    _builtin__push(SK_bool, (SKVALUE){._bool = r});
}

SK_INLINE void _builtin__ge() {
    Stack_value b = _builtin__pop();
    Stack_value a = _builtin__pop();
    bool r;
    switch (a.t) {
        case SK_bool: r = a.v._bool >= b.v._bool; break;
        case SK_f64: r = a.v._f64 >= b.v._f64; break;
        case SK_f32: r = a.v._f32 >= b.v._f32; break;
        case SK_s64: r = a.v._s64 >= b.v._s64; break;
        case SK_s32: r = a.v._s32 >= b.v._s32; break;
        case SK_s16: r = a.v._s16 >= b.v._s16; break;
        case SK_s8: r = a.v._s8 >= b.v._s8; break;
        case SK_u64: r = a.v._u64 >= b.v._u64; break;
        case SK_u32: r = a.v._u32 >= b.v._u32; break;
        case SK_u16: r = a.v._u16 >= b.v._u16; break;
        case SK_u8: r = a.v._u8 >= b.v._u8; break;
        default: assert(false);
    }
    _builtin__push(SK_bool, (SKVALUE){._bool = r});
}

SK_INLINE void _builtin__lt() {
    Stack_value b = _builtin__pop();
    Stack_value a = _builtin__pop();
    bool r;
    switch (a.t) {
        case SK_bool: r = a.v._bool < b.v._bool; break;
        case SK_f64: r = a.v._f64 < b.v._f64; break;
        case SK_f32: r = a.v._f32 < b.v._f32; break;
        case SK_s64: r = a.v._s64 < b.v._s64; break;
        case SK_s32: r = a.v._s32 < b.v._s32; break;
        case SK_s16: r = a.v._s16 < b.v._s16; break;
        case SK_s8: r = a.v._s8 < b.v._s8; break;
        case SK_u64: r = a.v._u64 < b.v._u64; break;
        case SK_u32: r = a.v._u32 < b.v._u32; break;
        case SK_u16: r = a.v._u16 < b.v._u16; break;
        case SK_u8: r = a.v._u8 < b.v._u8; break;
        default: assert(false);
    }
    _builtin__push(SK_bool, (SKVALUE){._bool = r});
}

SK_INLINE void _builtin__le() {
    Stack_value b = _builtin__pop();
    Stack_value a = _builtin__pop();
    bool r;
    switch (a.t) {
        case SK_bool: r = a.v._bool <= b.v._bool; break;
        case SK_f64: r = a.v._f64 <= b.v._f64; break;
        case SK_f32: r = a.v._f32 <= b.v._f32; break;
        case SK_s64: r = a.v._s64 <= b.v._s64; break;
        case SK_s32: r = a.v._s32 <= b.v._s32; break;
        case SK_s16: r = a.v._s16 <= b.v._s16; break;
        case SK_s8: r = a.v._s8 <= b.v._s8; break;
        case SK_u64: r = a.v._u64 <= b.v._u64; break;
        case SK_u32: r = a.v._u32 <= b.v._u32; break;
        case SK_u16: r = a.v._u16 <= b.v._u16; break;
        case SK_u8: r = a.v._u8 <= b.v._u8; break;
        default: assert(false);
    }
    _builtin__push(SK_bool, (SKVALUE){._bool = r});
}

SK_PROGRAM void main__stanczyk();

int main() {
    // Initialize stack
    the_stack.top = -1;
    main__stanczyk();
    return 0;
}
