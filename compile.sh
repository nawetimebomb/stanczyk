#!/bin/bash

odin build src -show-timings -use-separate-modules -out:skc -strict-style -vet-using-stmt -vet-using-param -vet-style -vet-semicolon -debug
