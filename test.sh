#!/bin/bash

FAIL=0
SUCCESS=0
TOTAL=0
RED="\033[31m"
GREEN="\033[32m"
RESET="\033[0m"
PURPLE="\033[35m"
BOLD="\033[1m"

echo -e $PURPLE
base64 -d misc/logo.base64
echo -e "${BOLD}Stańczyk Test Suite"
echo -e $RESET


for FILE in tests/*.sk; do
    if [ -f "$FILE" ]; then
        TOTAL=$(($TOTAL + 1))
        TEST_SRC="${FILE%.*}"
        TEST_NAME="${TEST_SRC##*/}"

        ./skc ${TEST_SRC}.sk > result.txt

        RESULT=$(diff ${TEST_SRC}.txt result.txt)

        echo -e "${BOLD}-- $TEST_NAME${RESET}"

        if [ -z "$RESULT" ]; then
            echo -e "${GREEN}\t✔ success ${RESET}"
            SUCCESS=$(($SUCCESS + 1))
        else
            echo -e "${RED}\t✗ fail${RESET}"
            echo $RESULT
            FAIL=$(($FAIL + 1))
        fi

        rm result.txt
    fi
done

if [[ "$FAIL" -gt 0 ]]; then
    echo -e "$RED"
else
    echo -e "$GREEN"
fi
echo -e "${BOLD}Total tests: $TOTAL"
echo -e "Success: $SUCCESS // Failed: $FAIL${RESET}"
exit $FAIL
