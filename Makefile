CC=gcc
LIBS=-ledit -lm
FLAGS=-Wall -std=c99 -Wpedantic -g -ggdb -DDEBUG_MODE
SOURCE_FILES=src/*.c src/includes/*.c
OUT=nlc

# interpreter:
# 	@ $(CC) $(FLAGS) $(SOURCE_FILES) $(LIBS) -o $(OUT)

all:
	@ $(CC) $(FLAGS) vm/*.c -o skc
