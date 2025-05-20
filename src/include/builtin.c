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

#define _STRLIT0 (string){.buf=(byteptr)(""), .len=0}
#define _STRLIT(s) ((string){.buf=(byteptr)("" s), .len=(size(s)-1)})
#define _STRLEN(s, n) ((string){.buf=(byteptr)("" s), .len=n})

struct string {
    byteptr buf;
    int len;
};

union Stack_value {
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

    string _string;
};

#define STACK_MAX_SIZE 32767

typedef union Stack_value Stack_value;
typedef struct Program_stack Program_stack;

struct Program_stack {
    int top;
    Stack_value values[STACK_MAX_SIZE];
};

SK_PROGRAM Program_stack _stack;

SK_INLINE bool stack_is_empty() { return _stack.top <= 0; }
SK_INLINE bool stack_is_full() { return _stack.top == STACK_MAX_SIZE - 1; }
SK_INLINE void stack_push(Stack_value v) { _stack.values[++_stack.top] = v; }
SK_INLINE Stack_value stack_peek() { return _stack.values[_stack.top]; }
SK_INLINE Stack_value stack_pop() { Stack_value v = _stack.values[_stack.top]; _stack.top--; return v; }
SK_INLINE void stack_dup() { Stack_value v = stack_pop(); stack_push(v); stack_push(v); }
SK_INLINE void stack_swap() { Stack_value b = stack_pop(); Stack_value a = stack_pop(); stack_push(b); stack_push(a); }

SK_INLINE bool bool_pop() { return stack_pop()._bool; }
SK_INLINE f64 f64_pop() { return stack_pop()._f64; }
SK_INLINE f32 f32_pop() { return stack_pop()._f32; }
SK_INLINE s64 s64_pop() { return stack_pop()._s64; }
SK_INLINE s32 s32_pop() { return stack_pop()._s32; }
SK_INLINE s16 s16_pop() { return stack_pop()._s16; }
SK_INLINE s8 s8_pop() { return stack_pop()._s8; }
SK_INLINE u64 u64_pop() { return stack_pop()._u64; }
SK_INLINE u32 u32_pop() { return stack_pop()._u32; }
SK_INLINE u16 u16_pop() { return stack_pop()._u16; }
SK_INLINE u8 u8_pop() { return stack_pop()._u8; }
SK_INLINE string string_pop() { return stack_pop()._string; }

SK_INLINE void bool_push(bool v) { stack_push((Stack_value){ ._bool = v }); }
SK_INLINE void f64_push(f64 v) { stack_push((Stack_value){ ._f64 = v }); }
SK_INLINE void f32_push(f32 v) { stack_push((Stack_value){ ._f32 = v }); }
SK_INLINE void s64_push(s64 v) { stack_push((Stack_value){ ._s64 = v }); }
SK_INLINE void s32_push(s32 v) { stack_push((Stack_value){ ._s32 = v }); }
SK_INLINE void s16_push(s16 v) { stack_push((Stack_value){ ._s16 = v }); }
SK_INLINE void s8_push(s8 v) { stack_push((Stack_value){ ._s8 = v }); }
SK_INLINE void u64_push(u64 v) { stack_push((Stack_value){ ._u64 = v }); }
SK_INLINE void u32_push(u32 v) { stack_push((Stack_value){ ._u32 = v }); }
SK_INLINE void u16_push(u16 v) { stack_push((Stack_value){ ._u16 = v }); }
SK_INLINE void u8_push(u8 v) { stack_push((Stack_value){ ._u8 = v }); }
SK_INLINE void string_push(string v) { stack_push((Stack_value){ ._string = v }); }

SK_PROGRAM void bool_print() { printf("%s", bool_pop() ? "true" : "false"); }
SK_PROGRAM void bool_println() { printf("%s\n", bool_pop() ? "true" : "false"); }
SK_PROGRAM void f64_print() { printf("%g", f64_pop()); }
SK_PROGRAM void f64_println() { printf("%g\n", f64_pop()); }
SK_PROGRAM void f32_print() { printf("%f", f32_pop()); }
SK_PROGRAM void f32_println() { printf("%f\n", f32_pop()); }
SK_PROGRAM void s64_print() { printf("%li", s64_pop()); }
SK_PROGRAM void s64_println() { printf("%li\n", s64_pop()); }
SK_PROGRAM void s32_print() { printf("%i", s32_pop()); }
SK_PROGRAM void s32_println() { printf("%i\n", s32_pop()); }
SK_PROGRAM void s16_print() { printf("%hi", s16_pop()); }
SK_PROGRAM void s16_println() { printf("%hi\n", s16_pop()); }
SK_PROGRAM void s8_print() { printf("%i", (s32)s8_pop()); }
SK_PROGRAM void s8_println() { printf("%i\n", (s32)s8_pop()); }
SK_PROGRAM void u64_print() { printf("%lu", u64_pop()); }
SK_PROGRAM void u64_println() { printf("%lu\n", u64_pop()); }
SK_PROGRAM void u32_print() { printf("%u", u32_pop()); }
SK_PROGRAM void u32_println() { printf("%u\n", u32_pop()); }
SK_PROGRAM void u16_print() { printf("%hu", u16_pop()); }
SK_PROGRAM void u16_println() { printf("%hu\n", u16_pop()); }
SK_PROGRAM void u8_print() { printf("%u", (u32)u8_pop()); }
SK_PROGRAM void u8_println() { printf("%u\n", (u32)u8_pop()); }
SK_PROGRAM void string_print() { string v = string_pop(); printf("%.*s", v.len, v.buf); }
SK_PROGRAM void string_println() { string v = string_pop(); printf("%.*s\n", v.len, v.buf); }

SK_INLINE void f64_to_bool() { bool_push(f64_pop() > 0.0f ? true : false); }
SK_INLINE void f64_to_f32() { f32_push((f32)f64_pop()); }
SK_INLINE void f64_to_s64() { s64_push((s64)f64_pop()); }
SK_INLINE void f64_to_s32() { s32_push((s32)f64_pop()); }
SK_INLINE void f64_to_s16() { s16_push((s16)f64_pop()); }
SK_INLINE void f64_to_s8() { s8_push((s8)f64_pop()); }
SK_INLINE void f64_to_u64() { u64_push((u64)f64_pop()); }
SK_INLINE void f64_to_u32() { u32_push((u32)f64_pop()); }
SK_INLINE void f64_to_u16() { u16_push((u16)f64_pop()); }
SK_INLINE void f64_to_u8() { u8_push((u8)f64_pop()); }
//SK_INLINE void f64_to_string() { }

SK_INLINE void f32_to_bool() { bool_push(f32_pop() > 0.0f ? true : false); }
SK_INLINE void f32_to_f64() { f64_push((f64)f32_pop()); }
SK_INLINE void f32_to_s64() { s64_push((s64)f32_pop()); }
SK_INLINE void f32_to_s32() { s32_push((s32)f32_pop()); }
SK_INLINE void f32_to_s16() { s16_push((s16)f32_pop()); }
SK_INLINE void f32_to_s8() { s8_push((s8)f32_pop()); }
SK_INLINE void f32_to_u64() { u64_push((u64)f32_pop()); }
SK_INLINE void f32_to_u32() { u32_push((u32)f32_pop()); }
SK_INLINE void f32_to_u16() { u16_push((u16)f32_pop()); }
SK_INLINE void f32_to_u8() { u8_push((u8)f32_pop()); }
//SK_INLINE void f32_to_string() { }

SK_INLINE void s64_to_bool() { bool_push(s64_pop() > 0 ? true : false); }
SK_INLINE void s64_to_f64() { f64_push((f64)s64_pop()); }
SK_INLINE void s64_to_f32() { f32_push((f32)s64_pop()); }
SK_INLINE void s64_to_s32() { s32_push((s32)s64_pop()); }
SK_INLINE void s64_to_s16() { s16_push((s16)s64_pop()); }
SK_INLINE void s64_to_s8() { s8_push((s8)s64_pop()); }
SK_INLINE void s64_to_u64() { u64_push((u64)s64_pop()); }
SK_INLINE void s64_to_u32() { u32_push((u32)s64_pop()); }
SK_INLINE void s64_to_u16() { u16_push((u16)s64_pop()); }
SK_INLINE void s64_to_u8() { u8_push((u8)s64_pop()); }
// SK_INLINE void s64_to_string() { }

SK_INLINE void s32_to_bool() { bool_push(s32_pop() > 0 ? true : false); }
SK_INLINE void s32_to_f64() { f64_push((f64)s32_pop()); }
SK_INLINE void s32_to_f32() { f32_push((f32)s32_pop()); }
SK_INLINE void s32_to_s64() { s64_push((s64)s32_pop()); }
SK_INLINE void s32_to_s16() { s16_push((s16)s32_pop()); }
SK_INLINE void s32_to_s8() { s8_push((s8)s32_pop()); }
SK_INLINE void s32_to_u64() { u64_push((u64)s32_pop()); }
SK_INLINE void s32_to_u32() { u32_push((u32)s32_pop()); }
SK_INLINE void s32_to_u16() { u16_push((u16)s32_pop()); }
SK_INLINE void s32_to_u8() { u8_push((u8)s32_pop()); }
//SK_INLINE void s32_to_string() { }

SK_INLINE void s16_to_bool() { bool_push(s16_pop() > 0 ? true : false); }
SK_INLINE void s16_to_f64() { f64_push((f64)s16_pop()); }
SK_INLINE void s16_to_f32() { f32_push((f32)s16_pop()); }
SK_INLINE void s16_to_s64() { s64_push((s64)s16_pop()); }
SK_INLINE void s16_to_s32() { s32_push((s32)s16_pop()); }
SK_INLINE void s16_to_s8() { s8_push((s8)s16_pop()); }
SK_INLINE void s16_to_u64() { u64_push((u64)s16_pop()); }
SK_INLINE void s16_to_u32() { u32_push((u32)s16_pop()); }
SK_INLINE void s16_to_u16() { u16_push((u16)s16_pop()); }
SK_INLINE void s16_to_u8() { u8_push((u8)s16_pop()); }
//SK_INLINE void s16_to_string() { }

SK_INLINE void s8_to_bool() { bool_push(s8_pop() > 0 ? true : false); }
SK_INLINE void s8_to_f64() { f64_push((f64)s8_pop()); }
SK_INLINE void s8_to_f32() { f32_push((f32)s8_pop()); }
SK_INLINE void s8_to_s64() { s64_push((s64)s8_pop()); }
SK_INLINE void s8_to_s32() { s32_push((s32)s8_pop()); }
SK_INLINE void s8_to_s16() { s16_push((s16)s8_pop()); }
SK_INLINE void s8_to_u64() { u64_push((u64)s8_pop()); }
SK_INLINE void s8_to_u32() { u32_push((u32)s8_pop()); }
SK_INLINE void s8_to_u16() { u16_push((u16)s8_pop()); }
SK_INLINE void s8_to_u8() { u8_push((u8)s8_pop()); }
//SK_INLINE void s8_to_string() { }

SK_INLINE void u64_to_bool() { bool_push(u64_pop() > 0 ? true : false); }
SK_INLINE void u64_to_f64() { f64_push((f64)u64_pop()); }
SK_INLINE void u64_to_f32() { f32_push((f32)u64_pop()); }
SK_INLINE void u64_to_s64() { s64_push((s64)u64_pop()); }
SK_INLINE void u64_to_s32() { s32_push((s32)u64_pop()); }
SK_INLINE void u64_to_s16() { s16_push((s16)u64_pop()); }
SK_INLINE void u64_to_s8() { s8_push((s8)u64_pop()); }
SK_INLINE void u64_to_u32() { u32_push((u32)u64_pop()); }
SK_INLINE void u64_to_u16() { u16_push((u16)u64_pop()); }
SK_INLINE void u64_to_u8() { u8_push((u8)u64_pop()); }
//SK_INLINE void u64_to_string() { }

SK_INLINE void u32_to_bool() { bool_push(u32_pop() > 0 ? true : false); }
SK_INLINE void u32_to_f64() { f64_push((f64)u32_pop()); }
SK_INLINE void u32_to_f32() { f32_push((f32)u32_pop()); }
SK_INLINE void u32_to_s64() { s64_push((s64)u32_pop()); }
SK_INLINE void u32_to_s32() { s32_push((s32)u32_pop()); }
SK_INLINE void u32_to_s16() { s16_push((s16)u32_pop()); }
SK_INLINE void u32_to_s8() { s8_push((s8)u32_pop()); }
SK_INLINE void u32_to_u64() { u64_push((u64)u32_pop()); }
SK_INLINE void u32_to_u16() { u16_push((u16)u32_pop()); }
SK_INLINE void u32_to_u8() { u8_push((u8)u32_pop()); }
//SK_INLINE void u32_to_string() { }

SK_INLINE void u16_to_bool() { bool_push(u16_pop() > 0 ? true : false); }
SK_INLINE void u16_to_f64() { f64_push((f64)u16_pop()); }
SK_INLINE void u16_to_f32() { f32_push((f32)u16_pop()); }
SK_INLINE void u16_to_s64() { s64_push((s64)u16_pop()); }
SK_INLINE void u16_to_s32() { s32_push((s32)u16_pop()); }
SK_INLINE void u16_to_s16() { s16_push((s16)u16_pop()); }
SK_INLINE void u16_to_s8() { s8_push((s8)u16_pop()); }
SK_INLINE void u16_to_u64() { u64_push((u64)u16_pop()); }
SK_INLINE void u16_to_u32() { u32_push((u32)u16_pop()); }
SK_INLINE void u16_to_u8() { u8_push((u8)u16_pop()); }
//SK_INLINE void u16_to_string() { }

SK_INLINE void u8_to_bool() { bool_push(u8_pop() > 0 ? true : false); }
SK_INLINE void u8_to_f64() { f64_push((f64)u8_pop()); }
SK_INLINE void u8_to_f32() { f32_push((f32)u8_pop()); }
SK_INLINE void u8_to_s64() { s64_push((s64)u8_pop()); }
SK_INLINE void u8_to_s32() { s32_push((s32)u8_pop()); }
SK_INLINE void u8_to_s16() { s16_push((s16)u8_pop()); }
SK_INLINE void u8_to_s8() { s8_push((s8)u8_pop()); }
SK_INLINE void u8_to_u64() { u64_push((u64)u8_pop()); }
SK_INLINE void u8_to_u32() { u32_push((u32)u8_pop()); }
SK_INLINE void u8_to_u16() { u16_push((u16)u8_pop()); }
//SK_INLINE void u8_to_string() { }

SK_INLINE void string_to_bool() { bool_push(string_pop().len > 0 ? true : false); }

SK_INLINE void log_and() { bool_push(bool_pop() == true && bool_pop() == true); }
SK_INLINE void log_or() { bool_push(bool_pop() == true || bool_pop() == true); }

SK_INLINE void f64_eq() { f64 b = f64_pop(); f64 a = f64_pop(); bool_push(a == b); }
SK_INLINE void f32_eq() { f32 b = f32_pop(); f32 a = f32_pop(); bool_push(a == b); }
SK_INLINE void s64_eq() { s64 b = s64_pop(); s64 a = s64_pop(); bool_push(a == b); }
SK_INLINE void s32_eq() { s32 b = s32_pop(); s32 a = s32_pop(); bool_push(a == b); }
SK_INLINE void s16_eq() { s16 b = s16_pop(); s16 a = s16_pop(); bool_push(a == b); }
SK_INLINE void s8_eq() { s8 b = s8_pop(); s8 a = s8_pop(); bool_push(a == b); }
SK_INLINE void u64_eq() { u64 b = u64_pop(); u64 a = u64_pop(); bool_push(a == b); }
SK_INLINE void u32_eq() { u32 b = u32_pop(); u32 a = u32_pop(); bool_push(a == b); }
SK_INLINE void u16_eq() { u16 b = u16_pop(); u16 a = u16_pop(); bool_push(a == b); }
SK_INLINE void u8_eq() { u8 b = u8_pop(); u8 a = u8_pop(); bool_push(a == b); }
SK_INLINE void string_eq() { string b = string_pop(); string a = string_pop(); bool_push(a.len == b.len && memcmp(a.buf, b.buf, a.len) == 0); }

SK_INLINE void f64_ne() { f64 b = f64_pop(); f64 a = f64_pop(); bool_push(a != b); }
SK_INLINE void f32_ne() { f32 b = f32_pop(); f32 a = f32_pop(); bool_push(a != b); }
SK_INLINE void s64_ne() { s64 b = s64_pop(); s64 a = s64_pop(); bool_push(a != b); }
SK_INLINE void s32_ne() { s32 b = s32_pop(); s32 a = s32_pop(); bool_push(a != b); }
SK_INLINE void s16_ne() { s16 b = s16_pop(); s16 a = s16_pop(); bool_push(a != b); }
SK_INLINE void s8_ne() { s8 b = s8_pop(); s8 a = s8_pop(); bool_push(a != b); }
SK_INLINE void u64_ne() { u64 b = u64_pop(); u64 a = u64_pop(); bool_push(a != b); }
SK_INLINE void u32_ne() { u32 b = u32_pop(); u32 a = u32_pop(); bool_push(a != b); }
SK_INLINE void u16_ne() { u16 b = u16_pop(); u16 a = u16_pop(); bool_push(a != b); }
SK_INLINE void u8_ne() { u8 b = u8_pop(); u8 a = u8_pop(); bool_push(a != b); }
SK_INLINE void string_ne() { string b = string_pop(); string a = string_pop(); bool_push(a.len != b.len || memcmp(a.buf, b.buf, a.len) != 0); }

SK_INLINE void f64_gt() { f64 b = f64_pop(); f64 a = f64_pop(); bool_push(a > b); }
SK_INLINE void f32_gt() { f32 b = f32_pop(); f32 a = f32_pop(); bool_push(a > b); }
SK_INLINE void s64_gt() { s64 b = s64_pop(); s64 a = s64_pop(); bool_push(a > b); }
SK_INLINE void s32_gt() { s32 b = s32_pop(); s32 a = s32_pop(); bool_push(a > b); }
SK_INLINE void s16_gt() { s16 b = s16_pop(); s16 a = s16_pop(); bool_push(a > b); }
SK_INLINE void s8_gt() { s8 b = s8_pop(); s8 a = s8_pop(); bool_push(a > b); }
SK_INLINE void u64_gt() { u64 b = u64_pop(); u64 a = u64_pop(); bool_push(a > b); }
SK_INLINE void u32_gt() { u32 b = u32_pop(); u32 a = u32_pop(); bool_push(a > b); }
SK_INLINE void u16_gt() { u16 b = u16_pop(); u16 a = u16_pop(); bool_push(a > b); }
SK_INLINE void u8_gt() { u8 b = u8_pop(); u8 a = u8_pop(); bool_push(a > b); }

SK_INLINE void f64_ge() { f64 b = f64_pop(); f64 a = f64_pop(); bool_push(a >= b); }
SK_INLINE void f32_ge() { f32 b = f32_pop(); f32 a = f32_pop(); bool_push(a >= b); }
SK_INLINE void s64_ge() { s64 b = s64_pop(); s64 a = s64_pop(); bool_push(a >= b); }
SK_INLINE void s32_ge() { s32 b = s32_pop(); s32 a = s32_pop(); bool_push(a >= b); }
SK_INLINE void s16_ge() { s16 b = s16_pop(); s16 a = s16_pop(); bool_push(a >= b); }
SK_INLINE void s8_ge() { s8 b = s8_pop(); s8 a = s8_pop(); bool_push(a >= b); }
SK_INLINE void u64_ge() { u64 b = u64_pop(); u64 a = u64_pop(); bool_push(a >= b); }
SK_INLINE void u32_ge() { u32 b = u32_pop(); u32 a = u32_pop(); bool_push(a >= b); }
SK_INLINE void u16_ge() { u16 b = u16_pop(); u16 a = u16_pop(); bool_push(a >= b); }
SK_INLINE void u8_ge() { u8 b = u8_pop(); u8 a = u8_pop(); bool_push(a >= b); }

SK_INLINE void f64_lt() { f64 b = f64_pop(); f64 a = f64_pop(); bool_push(a < b); }
SK_INLINE void f32_lt() { f32 b = f32_pop(); f32 a = f32_pop(); bool_push(a < b); }
SK_INLINE void s64_lt() { s64 b = s64_pop(); s64 a = s64_pop(); bool_push(a < b); }
SK_INLINE void s32_lt() { s32 b = s32_pop(); s32 a = s32_pop(); bool_push(a < b); }
SK_INLINE void s16_lt() { s16 b = s16_pop(); s16 a = s16_pop(); bool_push(a < b); }
SK_INLINE void s8_lt() { s8 b = s8_pop(); s8 a = s8_pop(); bool_push(a < b); }
SK_INLINE void u64_lt() { u64 b = u64_pop(); u64 a = u64_pop(); bool_push(a < b); }
SK_INLINE void u32_lt() { u32 b = u32_pop(); u32 a = u32_pop(); bool_push(a < b); }
SK_INLINE void u16_lt() { u16 b = u16_pop(); u16 a = u16_pop(); bool_push(a < b); }
SK_INLINE void u8_lt() { u8 b = u8_pop(); u8 a = u8_pop(); bool_push(a < b); }

SK_INLINE void f64_le() { f64 b = f64_pop(); f64 a = f64_pop(); bool_push(a <= b); }
SK_INLINE void f32_le() { f32 b = f32_pop(); f32 a = f32_pop(); bool_push(a <= b); }
SK_INLINE void s64_le() { s64 b = s64_pop(); s64 a = s64_pop(); bool_push(a <= b); }
SK_INLINE void s32_le() { s32 b = s32_pop(); s32 a = s32_pop(); bool_push(a <= b); }
SK_INLINE void s16_le() { s16 b = s16_pop(); s16 a = s16_pop(); bool_push(a <= b); }
SK_INLINE void s8_le() { s8 b = s8_pop(); s8 a = s8_pop(); bool_push(a <= b); }
SK_INLINE void u64_le() { u64 b = u64_pop(); u64 a = u64_pop(); bool_push(a <= b); }
SK_INLINE void u32_le() { u32 b = u32_pop(); u32 a = u32_pop(); bool_push(a <= b); }
SK_INLINE void u16_le() { u16 b = u16_pop(); u16 a = u16_pop(); bool_push(a <= b); }
SK_INLINE void u8_le() { u8 b = u8_pop(); u8 a = u8_pop(); bool_push(a <= b); }

SK_INLINE void f64_plus() { f64 b = f64_pop(); f64 a = f64_pop(); f64_push(a + b); }
SK_INLINE void f32_plus() { f32 b = f32_pop(); f32 a = f32_pop(); f32_push(a + b); }
SK_INLINE void s64_plus() { s64 b = s64_pop(); s64 a = s64_pop(); s64_push(a + b); }
SK_INLINE void s32_plus() { s32 b = s32_pop(); s32 a = s32_pop(); s32_push(a + b); }
SK_INLINE void s16_plus() { s16 b = s16_pop(); s16 a = s16_pop(); s16_push(a + b); }
SK_INLINE void s8_plus() { s8 b = s8_pop(); s8 a = s8_pop(); s8_push(a + b); }
SK_INLINE void u64_plus() { u64 b = u64_pop(); u64 a = u64_pop(); u64_push(a + b); }
SK_INLINE void u32_plus() { u32 b = u32_pop(); u32 a = u32_pop(); u32_push(a + b); }
SK_INLINE void u16_plus() { u16 b = u16_pop(); u16 a = u16_pop(); u16_push(a + b); }
SK_INLINE void u8_plus() { u8 b = u8_pop(); u8 a = u8_pop(); u8_push(a + b); }
SK_INLINE void string_plus() {
    string b = string_pop();
    string a = string_pop();
    int new_len = a.len + b.len;
    byteptr new_str = (byteptr)malloc(sizeof(byte) * new_len);
    { // Unsafe
        memcpy(new_str, a.buf, a.len);
        memcpy(new_str + a.len, b.buf, b.len);
        new_str[new_len] = 0;
    }
    string_push((string){.buf = new_str, .len = new_len});
}

SK_INLINE void f64_minus() { f64 b = f64_pop(); f64 a = f64_pop(); f64_push(a - b); }
SK_INLINE void f32_minus() { f32 b = f32_pop(); f32 a = f32_pop(); f32_push(a - b); }
SK_INLINE void s64_minus() { s64 b = s64_pop(); s64 a = s64_pop(); s64_push(a - b); }
SK_INLINE void s32_minus() { s32 b = s32_pop(); s32 a = s32_pop(); s32_push(a - b); }
SK_INLINE void s16_minus() { s16 b = s16_pop(); s16 a = s16_pop(); s16_push(a - b); }
SK_INLINE void s8_minus() { s8 b = s8_pop(); s8 a = s8_pop(); s8_push(a - b); }
SK_INLINE void u64_minus() { u64 b = u64_pop(); u64 a = u64_pop(); u64_push(a - b); }
SK_INLINE void u32_minus() { u32 b = u32_pop(); u32 a = u32_pop(); u32_push(a - b); }
SK_INLINE void u16_minus() { u16 b = u16_pop(); u16 a = u16_pop(); u16_push(a - b); }
SK_INLINE void u8_minus() { u8 b = u8_pop(); u8 a = u8_pop(); u8_push(a - b); }

SK_INLINE void s64_modulo() { s64 b = s64_pop(); s64 a = s64_pop(); s64_push(a % b); }
SK_INLINE void s32_modulo() { s32 b = s32_pop(); s32 a = s32_pop(); s32_push(a % b); }
SK_INLINE void s16_modulo() { s16 b = s16_pop(); s16 a = s16_pop(); s16_push(a % b); }
SK_INLINE void s8_modulo() { s8 b = s8_pop(); s8 a = s8_pop(); s8_push(a % b); }
SK_INLINE void u64_modulo() { u64 b = u64_pop(); u64 a = u64_pop(); u64_push(a % b); }
SK_INLINE void u32_modulo() { u32 b = u32_pop(); u32 a = u32_pop(); u32_push(a % b); }
SK_INLINE void u16_modulo() { u16 b = u16_pop(); u16 a = u16_pop(); u16_push(a % b); }
SK_INLINE void u8_modulo() { u8 b = u8_pop(); u8 a = u8_pop(); u8_push(a % b); }

SK_INLINE void f64_multiply() { f64 b = f64_pop(); f64 a = f64_pop(); f64_push(a * b); }
SK_INLINE void f32_multiply() { f32 b = f32_pop(); f32 a = f32_pop(); f32_push(a * b); }
SK_INLINE void s64_multiply() { s64 b = s64_pop(); s64 a = s64_pop(); s64_push(a * b); }
SK_INLINE void s32_multiply() { s32 b = s32_pop(); s32 a = s32_pop(); s32_push(a * b); }
SK_INLINE void s16_multiply() { s16 b = s16_pop(); s16 a = s16_pop(); s16_push(a * b); }
SK_INLINE void s8_multiply() { s8 b = s8_pop(); s8 a = s8_pop(); s8_push(a * b); }
SK_INLINE void u64_multiply() { u64 b = u64_pop(); u64 a = u64_pop(); u64_push(a * b); }
SK_INLINE void u32_multiply() { u32 b = u32_pop(); u32 a = u32_pop(); u32_push(a * b); }
SK_INLINE void u16_multiply() { u16 b = u16_pop(); u16 a = u16_pop(); u16_push(a * b); }
SK_INLINE void u8_multiply() { u8 b = u8_pop(); u8 a = u8_pop(); u8_push(a * b); }

SK_INLINE void f64_divide() { f64 b = f64_pop(); f64 a = f64_pop(); f64_push(a / b); }
SK_INLINE void f32_divide() { f32 b = f32_pop(); f32 a = f32_pop(); f32_push(a / b); }
SK_INLINE void s64_divide() { s64 b = s64_pop(); s64 a = s64_pop(); s64_push(a / b); }
SK_INLINE void s32_divide() { s32 b = s32_pop(); s32 a = s32_pop(); s32_push(a / b); }
SK_INLINE void s16_divide() { s16 b = s16_pop(); s16 a = s16_pop(); s16_push(a / b); }
SK_INLINE void s8_divide() { s8 b = s8_pop(); s8 a = s8_pop(); s8_push(a / b); }
SK_INLINE void u64_divide() { u64 b = u64_pop(); u64 a = u64_pop(); u64_push(a / b); }
SK_INLINE void u32_divide() { u32 b = u32_pop(); u32 a = u32_pop(); u32_push(a / b); }
SK_INLINE void u16_divide() { u16 b = u16_pop(); u16 a = u16_pop(); u16_push(a / b); }
SK_INLINE void u8_divide() { u8 b = u8_pop(); u8 a = u8_pop(); u8_push(a / b); }

SK_PROGRAM void main__stanczyk();

int main() {
    // Initialize stack
    _stack.top = -1;
    main__stanczyk();
    return 0;
}
