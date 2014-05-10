# SPARC Optim
======
A basic syntax checker and optimizer for SPARC assembly language

About
-----
Optim will remove `nop`s where it can guarentee that program execution
will not change (ignoring timing). It will also check the syntax of the
assembler code, and attempt to provide a semi-useful error message if problems
are found.

As of now, it only performs relativly simple manipulations of the AST to
remove `nop` instructions. It is particularly well suited to filling the
delay slots of `call` instructions, and will perform rudemetary data flow
analysis within that instruction's basic block.

Usage
-----
`ruby driver.rb <file>`, where <file> is the file to optimize.
Optim will write the optimized code to `stdout`, or any errors to `stderr`.

TODO
----
 - Parse address arguments in instructions, e.g. `ld [%fp - 4], %l0`
 - Optimize loop constructs (optimize across label declaration boundries)
 - Handle annuled branches
 - Check for other optimization cases (e.g. look for `.mul` or `.div` with powers of
   two and replace with a shift)

Notes
-----
It is not particularly well suited to optimizing loops (yet). This has mainly
been a project to write a simple lexer/parser/semantic analysis system, as well
as experement with implementing my own peephole optimizer.
