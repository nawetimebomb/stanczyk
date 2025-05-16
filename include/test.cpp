#include "stanczyk.h"

String string_value(Value v) {
    return v.as_string;
}

s32 s32_value(Value v) {
    return v.as_s32;
}

void stanczyk__main() {
    stack_push((Value){ .as_s32 = 5 });
    stack_push((Value){ .as_s32 = 5 });
    stack_push((Value){ .as_string = { "Hello", 5 }});
    string_println(string_value(stack_pop()));
    s32_println(s32_value(stack_pop()) + s32_value(stack_pop()));
}
