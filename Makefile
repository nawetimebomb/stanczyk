PROJECT_NAME  := Stanczyk
CC            := gcc
CFLAGS        := -Wall -std=c99 -Wpedantic
RELEASE_FLAGS := -O3
DEBUG_FLAGS   := -g -ggdb -O0
NAME          := skc

default: main

main:
	@ go build -o ./skc ./code

go:
	@ go build -o ./skc ./code
