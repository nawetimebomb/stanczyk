PROJECT_NAME  := Stanczyk
CC            := gcc
CFLAGS        := -Wall -std=c99 -Wpedantic
RELEASE_FLAGS := -O3
DEBUG_FLAGS   := -DDEBUG_PRINT_CODE -DDEBUG_TIME_LOG -g -ggdb -O0
DEBUG_TRACE   := -DDEBUG_TRACE_EXECUTION
NAME          := skc
SRC  := $(wildcard src/*.c)

default: main

main:
	@ $(CC) $(CFLAGS) $(RELEASE_FLAGS) $(SRC) -o $(NAME)

debug:
	@ $(CC) $(CFLAGS) $(DEBUG_FLAGS) $(SRC) -o $(NAME)

trace:
	@ $(CC) $(CFLAGS) $(DEBUG_FLAGS) $(DEBUG_TRACE) $(SRC) -o $(NAME)
