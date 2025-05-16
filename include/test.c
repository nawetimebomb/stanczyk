#include "stanczyk.h"

skc_program void stanczyk__main() {
    push_s32(5);
    push_s32(2);
    push_string((String){ "Test", 4 });
    push_string((String){ "\n", 1 });
    push_string((String){ "Test", 4 });
    print_string(pop_string());
    print_string(pop_string());
    println_string(pop_string());
    println_s32(pop_s32() + pop_s32());
}
