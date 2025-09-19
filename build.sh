#!/bin/bash

BIN_NAME=skc
COMMAND="$1"

odin build src -use-separate-modules -out:$BIN_NAME -strict-style -vet-using-stmt -vet-using-param -vet-style -vet-semicolon -debug

if [ "$?" == 0 ]; then
    if [ "$COMMAND" == "test" ]; then
        ./test.sh
    fi
fi


if [ "$?" == 0 ]; then
  if [ "$COMMAND" == "run" ]; then
    skc sandbox/test.sk -debug

    if [ "$?" == 0 ]; then
       echo -e "\nProgram result:\n"
       # cat sandbox/test.c
       ./sandbox/test
    fi
  fi
fi
