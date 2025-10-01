<p align="center">
   <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/7/78/Jan_Matejko%2C_Sta%C5%84czyk.jpg/2560px-Jan_Matejko%2C_Sta%C5%84czyk.jpg" alt="Jan Matejko's Stańczyk" style="width:75%" />
   <br />
   A Concatenative Type Safe Stack-Based Programming Language
   <br />
   <br />
   <img alt="GitHub commit activity" src="https://img.shields.io/github/commit-activity/w/nawetimebomb/stanczyk">
   <img alt="GitHub Actions Workflow Status" src="https://img.shields.io/github/actions/workflow/status/nawetimebomb/stanczyk/ci.yml">
   <img alt="GitHub License" src="https://img.shields.io/github/license/nawetimebomb/stanczyk">
</p>

# The Stańczyk Programming Language

**NOTE: This is a work in progress, things can change without any notice. Use with discretion.**

[Stańczyk] is a general-purpose stack-based programming language insired in Forth that prefer words over symbols and strive on trying to be easy to read by anyone. It uses Reverse Polish Notation, which also inspired the name of this language (plus my admiration to Jan Matejko's art), because it makes it easier to parse for the compiler and for the Human eye without the need of extra parenthesis. The language compiles to Assembly and it is trying to be compatible with all the major platforms. The backend compiler supported for now is `fasm`, although it is planned to support multiple backends. At the moment of this writing, the compiler is written in Odin.

Website: https://stanczyk-lang.org

[Stańczyk]: https://stanczyk-lang.org

```stanczyk
proc main
  "Hello, Stańczyk" print
;
```

## Documentation

### [Getting Started](https://stanczyk-lang.org)

Instructions to download and compile Stańczyk.

### [Learning Stańczyk](docs/overview.md)

Learn how to use and make programs in Stańczyk.

### Dependencies

The following is required to compile and use Stańczyk:

* [Odin](https://github.com/odin-lang/Odin) - To compile the compiler
* [gcc](https://gcc.gnu.org/) - To compile the output of this compiler into a binary

### Unit tests

After you get the Stańczyk compiler executable, you can run `./test.sh`.
