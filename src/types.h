#ifndef NLISP_TYPES_H
#define NLISP_TYPES_H

#include <stdio.h>
#include <stdint.h>
#include <float.h>

#define Kilobytes(value) ((value)*1024LL)
#define Megabytes(value) (Kilobytes(value)*1024LL)
#define Gigabytes(value) (Megabytes(value)*1024LL)
#define Terabytes(value) (Gigabytes(value)*1024LL)

/****************
 *              *
 *  BASE TYPES  *
 *              *
 ****************/
typedef uint8_t   u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;

typedef int8_t    i8;
typedef int16_t  i16;
typedef int32_t  i32;
typedef int64_t  i64;

// f32/64 => signed floats;
// r32/64 => unsigned floats;
typedef float  f32;
typedef double f64;

typedef float  r32;
typedef double r64;

#endif
