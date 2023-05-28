# The Stańczyk Programming Language

![Build](https://img.shields.io/appveyor/build/elnawe/stanczyk)
![Commits](https://img.shields.io/github/commit-activity/w/elnawe/stanczyk)
![LICENSE](https://img.shields.io/github/license/elnawe/stanczyk)

```
            ¿«fº"└└-.`└└*∞▄_              ╓▄∞╙╙└└└╙╙*▄▄
         J^. ,▄▄▄▄▄▄_      └▀████▄ç    JA▀            └▀v
       ,┘ ▄████████████▄¿     ▀██████▄▀└      ╓▄██████▄¿ "▄_
      ,─╓██▀└└└╙▀█████████      ▀████╘      ▄████████████_`██▄
     ;"▄█└      ,██████████-     ▐█▀      ▄███████▀▀J█████▄▐▀██▄
     ▌█▀      _▄█▀▀█████████      █      ▄██████▌▄▀╙     ▀█▐▄,▀██▄
    ▐▄▀     A└-▀▌  █████████      ║     J███████▀         ▐▌▌╙█µ▀█▄
  A╙└▀█∩   [    █  █████████      ▌     ███████H          J██ç ▀▄╙█_
 █    ▐▌    ▀▄▄▀  J█████████      H    ████████          █    █  ▀▄▌
  ▀▄▄█▀.          █████████▌           ████████          █ç__▄▀ ╓▀└ ╙%_
                 ▐█████████      ▐    J████████▌          .└╙   █¿   ,▌
                 █████████▀╙╙█▌└▐█╙└██▀▀████████                 ╙▀▀▀▀
                ▐██▀┘Å▀▄A └▓█╓▐█▄▄██▄J▀@└▐▄Å▌▀██▌
                █▄▌▄█M╨╙└└-           .└└▀**▀█▄,▌
                ²▀█▄▄L_                  _J▄▄▄█▀└
                     └╙▀▀▀▀▀MMMR████▀▀▀▀▀▀▀└


 ███████╗████████╗ █████╗ ███╗   ██╗ ██████╗███████╗██╗   ██╗██╗  ██╗
 ██╔════╝╚══██╔══╝██╔══██╗████╗  ██║██╔════╝╚══███╔╝╚██╗ ██╔╝██║ ██╔╝
 ███████╗   ██║   ███████║██╔██╗ ██║██║       ███╔╝  ╚████╔╝ █████╔╝
 ╚════██║   ██║   ██╔══██║██║╚██╗██║██║      ███╔╝    ╚██╔╝  ██╔═██╗
 ███████║   ██║   ██║  ██║██║ ╚████║╚██████╗███████╗   ██║   ██║  ██╗
 ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝
```

**NOTE: This is a work in progress, things can change without any notice. Use with discretion.**

This repository contains the source code for [Stańczyk]. You can find the compiler, standard library and documentation.

[Stańczyk]: https://stanczyk-lang.org

## What is Stańczyk?

Stańczyk is a [concatenative](https://en.wikipedia.org/wiki/Concatenative_programming_language) Programming Language that compiles to Assembly and then to an executable using the GCC back-end. It writes in Reverse Polish Notation and fits into the [stack-oriented programming paradigm](https://en.wikipedia.org/wiki/Stack-oriented_programming).

## Installation

- TODO: Add installation

### Dependencies

Make sure you have the following dependencies in your system before building Stańczyk:

* `git`
* `gcc` (build the source and also used to build the Assembly output)

## My first program

A simple *Hello, Stańczyk* program could be:

```
#include "io"

"Hello, Stańczyk\n" write
```

You can find more examples on [demos](demo)

## Unit tests

After you get the Stańczyk Compiler executable, you can run `./test.sh`.
