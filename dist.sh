#!/bin/bash

odin build src -out:skc -o:speed -strict-style -vet -vet-using-stmt -vet-using-param -vet-style -vet-semicolon -vet-cast

./test.sh
