PROJECT_NAME  := Stanczyk
NAME          := ./skc
CODE          := ./code

default: main

main:
	@ go build -o $(NAME) $(CODE)
