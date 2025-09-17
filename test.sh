#!/bin/bash

# If save is provided, (like `./test.sh save`) the test runner will automatically save the results
# into a .txt file and make sure the tests runs. This helps to make sure I have updated tests when needed.

SKC_EXEC="./skc"
FAIL=0
SUCCESS=0
TOTAL=0
RED="\033[91m"
GREEN="\033[92m"
RESET="\033[0m"
PURPLE="\033[95m"
BOLD="\033[1m"

ERRORS=""

echo -e $PURPLE
echo -e '
┏━  The Stańczyk Programming Language  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                                                                      ┃
┃            ¿«fº"└└-.`└└*∞▄_              ╓▄∞╙╙└└└╙╙*▄▄               ┃
┃         J^. ,▄▄▄▄▄▄_      └▀████▄ç    JA▀            └▀v             ┃
┃       ,┘ ▄████████████▄¿     ▀██████▄▀└      ╓▄██████▄¿ "▄_          ┃
┃      ,─╓██▀└└└╙▀█████████      ▀████╘      ▄████████████_`██▄        ┃
┃     ;"▄█└      ,██████████-     ▐█▀      ▄███████▀▀J█████▄▐▀██▄      ┃
┃     ▌█▀      _▄█▀▀█████████      █      ▄██████▌▄▀╙     ▀█▐▄,▀██▄    ┃
┃    ▐▄▀     A└-▀▌  █████████      ║     J███████▀         ▐▌▌╙█µ▀█▄   ┃
┃  A╙└▀█∩   [    █  █████████      ▌     ███████H          J██ç ▀▄╙█_  ┃
┃ █    ▐▌    ▀▄▄▀  J█████████      H    ████████          █    █  ▀▄▌  ┃
┃  ▀▄▄█▀.          █████████▌           ████████          █ç__▄▀ ╓▀└╙%_┃
┃                 ▐█████████      ▐    J████████▌          .└╙   █¿  ,▌┃
┃                 █████████▀╙╙█▌└▐█╙└██▀▀████████                 ╙▀▀▀ ┃
┃                ▐██▀┘Å▀▄A └▓█╓▐█▄▄██▄J▀@└▐▄Å▌▀██▌                     ┃
┃                █▄▌▄█M╨╙└└-           .└└▀**▀█▄,▌                     ┃
┃                ²▀█▄▄L_                  _J▄▄▄█▀└                     ┃
┃                     └╙▀▀▀▀▀MMMR████▀▀▀▀▀▀▀└                          ┃
┃                                                                      ┃
┃                                                                      ┃
┃ ███████╗████████╗ █████╗ ███╗   ██╗ ██████╗███████╗██╗   ██╗██╗  ██╗ ┃
┃ ██╔════╝╚══██╔══╝██╔══██╗████╗  ██║██╔════╝╚══███╔╝╚██╗ ██╔╝██║ ██╔╝ ┃
┃ ███████╗   ██║   ███████║██╔██╗ ██║██║       ███╔╝  ╚████╔╝ █████╔╝  ┃
┃ ╚════██║   ██║   ██╔══██║██║╚██╗██║██║      ███╔╝    ╚██╔╝  ██╔═██╗  ┃
┃ ███████║   ██║   ██║  ██║██║ ╚████║╚██████╗███████╗   ██║   ██║  ██╗ ┃
┃ ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ┃
┃                                                                      ┃'

echo -ne $RESET

for FILE in tests/*.sk; do
    if [ -f "$FILE" ]; then
        TOTAL=$(($TOTAL + 1))
        TEST_SRC="${FILE%.*}"
        TEST_NAME="${TEST_SRC##*/}"

        if [ "$1" == "save" ]; then
            ${SKC_EXEC} ${TEST_SRC}.sk -silent > ${TEST_SRC}.txt
        fi

        if [ ! -f "${TEST_SRC}.txt" ]; then
            continue
        fi

        ${SKC_EXEC} ${TEST_SRC}.sk -silent

        if [ "$?" == 0 ]; then
            ./${TEST_SRC} > result.txt

            RESULT=$(diff ${TEST_SRC}.txt result.txt)
            echo -en $PURPLE'┃'
            printf "${RESET}${BOLD} ¤ %-56s${RESET}" $TEST_NAME

            if [ -z "$RESULT" ]; then
                echo -ne "${GREEN}✔ success${RESET}"
                SUCCESS=$(($SUCCESS + 1))
            else
                echo -ne "${RED}✗ failed${RESET} "
                FAIL=$(($FAIL + 1))
                if [ "$1" == "show" ]; then
                    ERRORS+="${BOLD}  ¤ ${TEST_NAME}.sk${RESET}\n\t- ${RESULT}\n"
                fi
            fi

            echo -e $PURPLE'  ┃'
            rm result.txt
            rm ${TEST_SRC}
        else
            echo -en $PURPLE'┃'
            printf "${RESET}${BOLD} ¤ %-56s${RESET}" $TEST_NAME

            echo -ne "${RED}✗ failed${RESET} "
            FAIL=$(($FAIL + 1))
            if [ "$1" == "show" ]; then
                ERRORS+="${BOLD}  ¤ ${TEST_NAME}.sk${RESET}\n\t- ${RESULT}\n"
            fi

           echo -e $PURPLE'  ┃'
        fi
    fi
done

SKIPPED=$(($TOTAL - $SUCCESS - $FAIL))

RCOLOR=""
if [[ "$FAIL" -gt 0 ]]; then
    RCOLOR="$RED"
else
    RCOLOR="$GREEN"
fi
echo -e $PURPLE'┃                                                                      ┃
┃                                                                      ┃'
printf "${PURPLE}┃${RESET}                     ${RCOLOR}${BOLD}TOTAL %2d :: Success %2d | Fails %2d | Skipped %2d ${RESET}" $TOTAL $SUCCESS $FAIL $SKIPPED
echo -e $PURPLE'  ┃'
echo -e $PURPLE'┃                                                                      ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  The Stańczyk Programming Language  ━┛'

if [ "$1" == "show" ]; then
    echo -e "${RESET}"
    echo -e "Errors:"
    echo -e "${ERRORS}"
fi

echo -e ${RESET}

exit $FAIL
