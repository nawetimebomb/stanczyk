CC          := gcc
FLAGS       := -Wall -std=c99 -Wpedantic
OUT_FOLDER  := build
DEBUG_FLAGS := -DDEBUG_PRINT_CODE -DDEBUG_TRACE_EXECUTION -g -ggdb -O0

default: main

# clean:
# 	@ rm -rf $(BUILD_DIR)
# 	@ mkdir -p $(BUILD_DIR)

main:
	@ $(CC) $(FLAGS) -O3 src/*.c -o skc

debug:
	@ $(CC) $(FLAGS) src/*.c -o skc $(DEBUG_FLAGS)
