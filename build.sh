#!/bin/bash

BIN_NAME=skc

odin build src -use-separate-modules -out:$BIN_NAME -strict-style -vet-using-stmt -vet-using-param -vet-style -vet-semicolon -debug

if [ "$?" == 0 ]; then
  if [ ! -z "$1" ]; then
    skc sandbox/test.sk

    if [ "$?" == 0 ]; then
       echo -e "\nProgram result:\n"
       ./sandbox/test
    fi
  fi
fi

#if [ "$?" == 0 ]; then
#    if [ ! -z "$1" ]; then
#        ./test.sh
#    fi
#fi
