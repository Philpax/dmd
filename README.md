# Moonshot

Moonshot is a fork of DMD, the reference compiler for the D programming language.
It implements a Lua 5.x backend for the `@safe` subset of D, based on AST conversion.
It aims to compile a reasonable subset of `@safe` code, so that high-level D can be used
in scripting environments (i.e. games, scriptable applications, and more.)

This project was inspired by Adam D. Ruppe's [dtojs](https://github.com/adamdruppe/dtojs),
which took a similar approach.

## Features
Currently, its support of D functionality is limited, but includes:
* **Functions**: free, literal
* **Expressions**: strings, numbers, unary/binary operations (inc. assignment), calls
* **Arrays**: literals, indexing
* **Control flow**: `if`, `for`, `while`, `do`, `foreach` (inc. tuples), `break`, `switch`
* **Structs**: `init`, methods, member variables, enough to use ranges 
* **`extern (Lua)` binding**: functions, namespaces, classes/structs, op overloading
* **Metaprogramming**: should work Out Of The Box™, including templates, mixins, and more

Notable exclusions include:
* Pointers/references
* Slices
* `continue`, `goto`
* Classes
* Exceptions
* `try finally`, destructors, `scope (exit)`
* Associative arrays
* Any kind of optimised code generation
* ...and more.

These missing features should hopefully be implemented over time.

## Running
To use, compile your D source with Moonshot with the `-lua` switch.

Test cases can be found in `test/lua`, as well as work on a "runtime"; this
will be moved out when appropriate. To run tests, use `rdmd lua_test.d` in
the `test` directory.

Any references to Phobos in tests currently refer to unmodified Phobos.

# DMD readme

To report a problem or browse the list of open bugs, please visit the
[bug tracker](http://issues.dlang.org/).

For more information, including instructions for compiling, installing, and
hacking on DMD, check the [contribution guide](CONTRIBUTING.md) and
visit the [D Wiki](http://wiki.dlang.org/DMD).

All significant contributors to DMD source code, via github, bugzilla, email,
wiki, the D forums, etc., please assign copyright to those
DMD source code changes to the D Language Foundation. Please send
an email to walter@digitalmars.com with the statement:

"I hereby assign copyright in my contributions to DMD to the D Language Foundation"

and include your name and date.
