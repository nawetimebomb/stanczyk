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
#include <string.h>

#include "memory.h"
#include "object.h"
#include "constant.h"

#define ALLOCATE_OBJECT(type, object_type)               \
    (type*)allocate_object(sizeof(type), object_type)

static Object* allocate_object(size_t size, ObjectType type) {
    Object* object = (Object*)reallocate(NULL, 0, size);
    object->type = type;
    return object;
}

Function *new_function() {
    Function *function = ALLOCATE_OBJECT(Function, OBJECT_FUNCTION);
    function->arity = 0;
    function->name = NULL;
    init_chunk(&function->chunk);
    return function;
}

CFunction *new_cfunction() {
    CFunction *cfunction = ALLOCATE_OBJECT(CFunction, OBJECT_CFUNCTION);
    cfunction->start = 4;
    cfunction->count = 0;
    cfunction->capacity = 0;
    cfunction->name = NULL;
    cfunction->cname = NULL;
    cfunction->regs = NULL;
    return cfunction;
}

void cfunction_add_reg(CFunction *cfunction, String *reg) {
    if (cfunction->capacity < cfunction->count + 1) {
        int prev_cap = cfunction->capacity;
        cfunction->capacity = GROW_CAPACITY(prev_cap, cfunction->start);
        cfunction->regs = GROW_ARRAY(String *, cfunction->regs, prev_cap, cfunction->capacity);
    }

    cfunction->regs[cfunction->count] = reg;
    cfunction->count++;
}

static u32 hash_string(const char *key, int length) {
    u32 hash = 2166136261u;
    for (int i = 0; i < length; i++) {
        hash ^= (u8)key[i];
        hash *= 16777619;
    }
    return hash;
}

static String *allocate_string(char* chars, int length, u32 hash) {
    String *string = ALLOCATE_OBJECT(String, OBJECT_STRING);
    string->length = length;
    string->chars = chars;
    string->hash = hash;
    return string;
}

String *copy_string(const char *chars, int length) {
    u32 hash = hash_string(chars, length);
    char *heapChars = ALLOCATE(char, length + 1);
    memcpy(heapChars, chars, length);
    heapChars[length] = '\0';
    return allocate_string(heapChars, length, hash);
}

void print_object(Value value) {
    switch (OBJECT_TYPE(value)) {
        case OBJECT_STRING: printf("%s", AS_CSTRING(value)); break;
        case OBJECT_FUNCTION: printf("<function %s>", AS_FUNCTION(value)->name->chars); break;
        case OBJECT_CFUNCTION: printf("<cfunction %s>", AS_CFUNCTION(value)->name->chars); break;
    }
}
