# The Stańczyk Programming Language Overview

## Introduction

This article will try to help you understand the Stańczyk Programming Language. If you have never used a concatenative stack-based language before, here's a brief explanation. Concatenative languages are programming languages where all expressions are functions and programs are built by function composition. This type of languages are usually written left-to-right, and although it has variables, usually the data is managed in the stack.

An example of function composition could be the following. While in C, Go, Odin or any other traditional language you have:

```
bar(foo(x))
```

...in Stańczyk you would have:

```stanczyk
x foo bar
```

We want to first push a value to the stack (`x`, which is in itself a function that means `push x to the stack`, which will be the value used by the function that follows it, `foo`, and the result of `foo` will be the value used by `bar`. What remains in the stack is the result of `bar`. The compiler will know how many inputs a function needs to run and how many outputs will produce in order to keep the execution sane, and this mostly happens during compile-time, meaning there's low risk of runtime errors.

### Install The Stańczyk Compiler

Read the [Getting Started with Stańczyk](getting-started.md) guide to learn more on how to get Stańczyk running on your computer.

### Hello, World!

Let's first start with the most famous program known so far, "Hello, World". We will make a modification and salute our hero, Stańczyk.

```stanczyk
using core.io ;

fn main
  "Hello, Stańczyk" println
;
```

Save this code to a `.sk` file and run it using `skc run <file>`.

## Lexicon and grammar

### Comments

As pretty much any programming language, comments are allowed in Stańczyk and can be used anywhere (while outside a string). Single line comments starts with `//`.

```stanczyk
// This is a comment

fn main // You can have comments here
  ...
;
```

### Numbers

Number literals are similar to any programming language. Inspired by Odin, Stańczyk allows to use underscore in numbers for better readability `1_000_000_000` (one billion). The default number type in Stańczyk is a 64-bit signed integer (unless the 32-bit compilation switch is enabled or the computer running the compiler runs also in 32 bits). If the number literal contains a point (`1.0` or `1.`) it will be considered `float` (64-bit floating point literal).

Binary literals can be prefixed with `0b`, octal literals with `0o` and hexadecimal literals by `0x`. But the Stańczyk developer should prefer the suffix form.

```stanczyk
255 // A signed integer literal
32767u // An unsigned integer literal
3.14 // A floating point literal
1f // Also a floating point literal, can also be '1.'
2b // A binary literal, also 0b10
8o // An octal literal, also 0o10
255x // A hexadecimal literal, also 0xff

2_000 // A signed integer of value 2000
1_3_3_7u // An unsigned integer of valie 1337
```

### String literals

Strings start and end with `"` (double quotes). Characters can be escaped with `\` to transform into an special character.

```stanczyk
"Hello"
"Line 1\nLine 2"
```

Stańczyk strings are the default type of string literals, but you can also specify a `cstring` literal by appending a `c` after the closing `"`.

```stanczyk
"Hello"c
```

The length of a string can be calculated at compile-time by using the word `len`.

```stanczyk
"Hello" len
```

### Words

The Stańczyk parser is straight forward. It will parse the code from left-to-right, token by token. The following order of parsing is used:

* The parser will test the starting of a word. If it starts with `"` (double quotes) or `'` (single quote) it will find the enclosing character and parse it as a string literal.
* If the word wasn't a string, then it will try to convert the content to a number. If it succeeds, it is going to be considered one of the number literals (integer, unsigned integer, etc.)
* Finally, it will be parsed as a `word`.

Words are the main entity in Stańczyk. A word can sometimes have many meanings and, in some context, have specific significance. There are some native words, some reserved words and then we have the user-defined words. Words are used in any type of declarations, can start and contain any character. Native words cannot be overriden, reserved words can have other meaning in some context. User-defined words might be reserved in some contexts.

```stanczyk
fn Stańczyk_Gąska "Stańczyk Gąska" println ; // prints "Stańczyk Gąska"
```

### Writing Stańczyk

Like most stack-based concatenative language, Stańczyk is written in [Reverse Polish notation](https://en.wikipedia.org/wiki/Reverse_Polish_notation), also known as Postfix notation. Meaning that values go first and operation goes last. This makes it so we can get rid of most parenthesis.

```stanczyk
7 6 + // equals 13
```

Everything in Stańczyk is a function, even number and string literals. Functions have effects on the stack and are measured by that factor. For example, the number 7 means "push 7 to the stack", while the native word "+" means "take the last 2 stack values, sum them up and push the result to the stack". You can use the main feature of concatenative programming language, composition, to construct a program that prints the result of an equation:

```stanczyk
7 6 + 2 * println // prints 26
```

...The above program does the following:

1. Push signed integer 7 to the stack. Stack effect [ 7 ].
2. Push signed integer 6 to the stack. Stack effect [ 7 6 ].
3. Pull two values from stack and sum them up. *Note:* the order of the operation happens from left-to-right as well, so the first pushed number will be the left operand, while the second will be the right. This is important because some operations care about the order of their operands. Stack effect [ 13 ] (7 + 6).
4. Push signed integer 2 to the stack. Stack effect [ 13 2 ].
5. Pull two values from stack and multiply them. [ 26 ] (13 * 2).
6. Pull one value from stack and print it to the screen. Stack effect: [ ] (prints: 26).

## Constant declarations

Constants are words that have an assigned value. This value cannot be changed and it will be used in compile-time as a literal. Constants can be explicitly typed, but if the type is inferred, when used, it will try to match the context (I.e. if an unsigned integer exists in the stack and an inferred number constant is used, it will be inserted into the stack as an unsigned integer).

```stanczyk
const name "Stańczyk" ; // When used it will push a string literal to the stack, but if the context requires a cstring, it will push be a cstring instead.
const last-name string "Gąska" ; // This is explicitly typed, so will always be treated as a Stańczyk string literal.
```

## Variable declarations

Unlike constants, variables can change and are evaluated at runtime. Variables are initialized to zero by default, meaning that when declaring a variable you can specify its value, its type or both.

```stanczyk
var name string ; // name will be "".
var age 42 ; // age will be of value 42 and inferred type of signed integer.
var can_jump bool true ; // can_jump is a boolean of value true.
```

### Using variables

Also unlike constants, variables don't push their value when used. Instead, they will push a reference to the variable and special words `get` or `set` can be used to retrieve or change its value respectively.

```stanczyk
"Stańczyk Gąska" name set // Will change the name variable to have value "Stańczyk Gąska"
name get println // prints Stańczyk Gąska
```
