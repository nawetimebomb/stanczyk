#include <stdio.h>
#include <stdint.h>

// Stanczyk Builtin Types
typedef int64_t  s64;
typedef int32_t  s32;
typedef int16_t  s16;
typedef int8_t   s8;
typedef uint64_t u64;
typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t  u8;
typedef int8_t   b8;
typedef double   f64;
typedef float    f32;

#define SK_EXPORT extern __declspec(dllexport)
#define SK_INLINE static inline
#define SK_STATIC static
#define STR_LIT(s) ((string){.data=(u8*)("" s), .length=(sizeof(s)-1)})
#define SK_TRUE  1
#define SK_FALSE 0

typedef struct string {
	u8* data;
	s64 length;
} string;

// Stanczyk Multireturn types

// Stanczyk Internal Procedures
SK_STATIC void print_b8(b8 v) { printf("%s\n", v == SK_TRUE ? "true" : "false"); }
SK_STATIC void print_u8(u8 v) { printf("%d\n", v); }
SK_STATIC void print_f64(f64 v) { printf("%g\n", v); }
SK_STATIC void print_s64(s64 v) { printf("%lli\n", v); }
SK_STATIC void print_u64(u64 v) { printf("%llu\n", v); }
SK_STATIC void print_string(string v) { printf("%s\n", v.data); }

// User Definitions
SK_STATIC void stanczyk__main();

// User Code
SK_STATIC void stanczyk__main(){
	s64 r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, r16, r17, r18, r19, r20, r21, r22, r23, r24, r25, r26, r27, r28, r29, r30, r31, r32, r33, r34, r35, r36, r37, r38, r39, r40, r41, r42, r43, r44, r45, r46, r47, r48, r49, r50, r51, r52, r53, r54, r55, r56, r57, r58, r59, r60, r61, r62, r63, r64, r65, r66, r67, r68, r69, r70, r71, r72, r73, r74, r75, r76, r77, r78, r79, r80, r81, r82, r83, r84;
_ip0:;	// PUSH_INT
	r0 = 2;
_ip1:;	// PUSH_INT
	r1 = 2;
_ip2:;	// BINARY_ADD
	r2 = r0 + r1;
_ip3:;	// PRINT
	print_s64(r2);
_ip4:;	// PUSH_INT
	r3 = 10;
_ip5:;	// PUSH_INT
	r4 = 1;
_ip6:;	// BINARY_ADD
	r5 = r3 + r4;
_ip7:;	// PUSH_INT
	r6 = 2;
_ip8:;	// BINARY_ADD
	r7 = r5 + r6;
_ip9:;	// PRINT
	print_s64(r7);
_ip10:;	// PUSH_INT
	r8 = 2;
_ip11:;	// PUSH_INT
	r9 = 3;
_ip12:;	// BINARY_ADD
	r10 = r8 + r9;
_ip13:;	// PUSH_INT
	r11 = 5;
_ip14:;	// BINARY_ADD
	r12 = r10 + r11;
_ip15:;	// PUSH_INT
	r13 = 3;
_ip16:;	// BINARY_ADD
	r14 = r12 + r13;
_ip17:;	// PRINT
	print_s64(r14);
_ip18:;	// PUSH_INT
	r15 = 2;
_ip19:;	// PUSH_INT
	r16 = 2;
_ip20:;	// BINARY_MINUS
	r17 = r15 - r16;
_ip21:;	// PRINT
	print_s64(r17);
_ip22:;	// PUSH_INT
	r18 = 25;
_ip23:;	// PUSH_INT
	r19 = 3;
_ip24:;	// BINARY_MINUS
	r20 = r18 - r19;
_ip25:;	// PUSH_INT
	r21 = 9;
_ip26:;	// BINARY_MINUS
	r22 = r20 - r21;
_ip27:;	// PRINT
	print_s64(r22);
_ip28:;	// PUSH_INT
	r23 = 50;
_ip29:;	// PUSH_INT
	r24 = 10;
_ip30:;	// BINARY_MINUS
	r25 = r23 - r24;
_ip31:;	// PUSH_INT
	r26 = 20;
_ip32:;	// BINARY_MINUS
	r27 = r25 - r26;
_ip33:;	// PUSH_INT
	r28 = 3;
_ip34:;	// BINARY_MINUS
	r29 = r27 - r28;
_ip35:;	// PUSH_INT
	r30 = 4;
_ip36:;	// BINARY_MINUS
	r31 = r29 - r30;
_ip37:;	// PRINT
	print_s64(r31);
_ip38:;	// PUSH_INT
	r32 = 2;
_ip39:;	// PUSH_INT
	r33 = 3;
_ip40:;	// BINARY_MULTIPLY
	r34 = r32 * r33;
_ip41:;	// PRINT
	print_s64(r34);
_ip42:;	// PUSH_INT
	r35 = 2;
_ip43:;	// PUSH_INT
	r36 = 2;
_ip44:;	// BINARY_MULTIPLY
	r37 = r35 * r36;
_ip45:;	// PUSH_INT
	r38 = 2;
_ip46:;	// BINARY_MULTIPLY
	r39 = r37 * r38;
_ip47:;	// PRINT
	print_s64(r39);
_ip48:;	// PUSH_INT
	r40 = 2;
_ip49:;	// PUSH_INT
	r41 = 2;
_ip50:;	// PUSH_INT
	r42 = 2;
_ip51:;	// PUSH_INT
	r43 = 2;
_ip52:;	// PUSH_INT
	r44 = 2;
_ip53:;	// BINARY_MULTIPLY
	r45 = r43 * r44;
_ip54:;	// BINARY_MULTIPLY
	r46 = r42 * r45;
_ip55:;	// BINARY_MULTIPLY
	r47 = r41 * r46;
_ip56:;	// BINARY_MULTIPLY
	r48 = r40 * r47;
_ip57:;	// PRINT
	print_s64(r48);
_ip58:;	// PUSH_INT
	r49 = 10;
_ip59:;	// PUSH_INT
	r50 = 2;
_ip60:;	// BINARY_SLASH
	r51 = r49 / r50;
_ip61:;	// PRINT
	print_s64(r51);
_ip62:;	// PUSH_INT
	r52 = 32;
_ip63:;	// PUSH_INT
	r53 = 2;
_ip64:;	// PUSH_INT
	r54 = 2;
_ip65:;	// PUSH_INT
	r55 = 2;
_ip66:;	// BINARY_SLASH
	r56 = r54 / r55;
_ip67:;	// BINARY_SLASH
	r57 = r53 / r56;
_ip68:;	// BINARY_SLASH
	r58 = r52 / r57;
_ip69:;	// PRINT
	print_s64(r58);
_ip70:;	// PUSH_INT
	r59 = 32;
_ip71:;	// PUSH_INT
	r60 = 2;
_ip72:;	// BINARY_SLASH
	r61 = r59 / r60;
_ip73:;	// PUSH_INT
	r62 = 2;
_ip74:;	// BINARY_SLASH
	r63 = r61 / r62;
_ip75:;	// PUSH_INT
	r64 = 2;
_ip76:;	// BINARY_SLASH
	r65 = r63 / r64;
_ip77:;	// PRINT
	print_s64(r65);
_ip78:;	// PUSH_INT
	r66 = 10;
_ip79:;	// PUSH_INT
	r67 = 3;
_ip80:;	// BINARY_MODULO
	r68 = r66 % r67;
_ip81:;	// PRINT
	print_s64(r68);
_ip82:;	// PUSH_INT
	r69 = 3;
_ip83:;	// PUSH_INT
	r70 = 4;
_ip84:;	// BINARY_ADD
	r71 = r69 + r70;
_ip85:;	// PUSH_INT
	r72 = 7;
_ip86:;	// BINARY_ADD
	r73 = r71 + r72;
_ip87:;	// PUSH_INT
	r74 = 1;
_ip88:;	// BINARY_MINUS
	r75 = r73 - r74;
_ip89:;	// PRINT
	print_s64(r75);
_ip90:;	// PUSH_INT
	r76 = 10;
_ip91:;	// PUSH_INT
	r77 = 5;
_ip92:;	// BINARY_SLASH
	r78 = r76 / r77;
_ip93:;	// PUSH_INT
	r79 = 3;
_ip94:;	// BINARY_ADD
	r80 = r78 + r79;
_ip95:;	// PUSH_INT
	r81 = 5;
_ip96:;	// BINARY_MULTIPLY
	r82 = r80 * r81;
_ip97:;	// PUSH_INT
	r83 = 12;
_ip98:;	// BINARY_MINUS
	r84 = r82 - r83;
_ip99:;	// PRINT
	print_s64(r84);
_ip100:;	// RETURN
	return;
}
int main(int argc, const char *argv){
	stanczyk__main();
	return 0;
}
