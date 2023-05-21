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
echo -e $RESET

for FILE in tests/*.sk; do
    if [ -f "$FILE" ]; then
        TOTAL=$(($TOTAL + 1))
        TEST_SRC="${FILE%.*}"
        TEST_NAME="${TEST_SRC##*/}"

        ./skc ${TEST_SRC}.sk > result.txt

        RESULT=$(diff ${TEST_SRC}.txt result.txt)
        printf "${BOLD} ¤ %-56s${RESET}" $TEST_NAME

        if [ -z "$RESULT" ]; then
            echo -e "${GREEN}✔ success${RESET}"
            SUCCESS=$(($SUCCESS + 1))
        else
            echo -e "${RED}✗ fail${RESET}"
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

printf "${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\n"
printf "┃  TOTAL %2d :: Success %2d | Fails %2d  ┃\n" $TOTAL $SUCCESS $FAIL
printf "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RESET}\n"

exit $FAIL
