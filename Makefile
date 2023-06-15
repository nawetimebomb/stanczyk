CC=gcc
FLAGS=-Wall -std=c99 -Wpedantic -g -ggdb -DDEBUG_MODE

all:
	@ $(CC) $(FLAGS) src/*.c -o skc
