PROJECT_NAME  := Stanczyk

all: compile

compile:
	STANCZYK=$(pwd) ./compile.sh t
