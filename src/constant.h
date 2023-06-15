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
#ifndef STANCZYK_CONSTANT_H
#define STANCZYK_CONSTANT_H

typedef struct Object Object;
typedef struct String String;

typedef enum {
    VALUE_INT,
    VALUE_FLOAT,
    VALUE_DTYPE,
    VALUE_OBJECT
} ValueType;

typedef enum {
    DATA_NULL,
    DATA_INT,
    DATA_BOOL,
    DATA_PTR
} DataType;

typedef struct {
    ValueType type;
    union {
        int inumber;
        float fnumber;
        Object *obj;
        DataType dtype;
    } as;
} Value;

typedef struct {
    int start;
    int capacity;
    int count;
    Value *values;
} ConstantArray;

#define IS_INT(value) ((value).type == VALUE_INT)
#define IS_FLOAT(value) ((value).type == VALUE_FLOAT)
#define IS_DTYPE(value) ((value).type == VALUE_DTYPE)
#define IS_OBJECT(value) ((value).type == VALUE_OBJECT)

#define AS_INT(value) ((value).as.inumber)
#define AS_FLOAT(value) ((value).as.fnumber)
#define AS_DTYPE(value) ((value).as.dtype)
#define AS_OBJECT(value) ((value).as.obj)

#define INT_VALUE(value) ((Value){VALUE_INT, {.inumber = value}})
#define FLOAT_VALUE(value) ((Value){VALUE_FLOAT, {.fnumber = value}})
#define DTYPE_VALUE(value) ((Value){VALUE_DTYPE, {.dtype = value}})
#define OBJECT_VALUE(object) ((Value){VALUE_OBJECT, {.obj = (Object *)object}})

void init_constants_array(ConstantArray *);
void write_constants_array(ConstantArray *, Value);
void free_constants_array(ConstantArray *);
void print_constant(Value value);

#endif
