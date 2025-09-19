PROJECT_NAME  := Stanczyk

all: compile

compile:
	STANCZYK_DIR=$(pwd) ./build.sh test
