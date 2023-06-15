PROJECT_NAME  := Stanczyk
CC            := gcc
CFLAGS        := -Wall -std=c99 -Wpedantic
RELEASE_FLAGS := -O3
DEBUG_FLAGS   := -DDEBUG_PRINT_CODE -DDEBUG_TRACE_EXECUTION -DDEBUG_TIME_LOG -g -ggdb -O0
NAME          := skc
SRC  := $(wildcard src/*.c)

default: main

main:
	@ $(CC) $(CFLAGS) $(RELEASE_FLAGS) $(SRC) -o $(NAME)

debug:
	@ $(CC) $(CFLAGS) $(DEBUG_FLAGS) $(SRC) -o $(NAME)
