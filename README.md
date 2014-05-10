# SPARC Optim
======
A basic syntax/sanity checker and peephole optimizer for SPARC assembly language

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

Optim will also perform basic code formatting to fix indentation and alignment.

Usage
-----
`ruby driver.rb <file>`, where <file> is the file to optimize.
Optim will write the optimized code to `stdout`, or any errors to `stderr`.

Example
-------

##### Reordering instructions into the delay slots of branches, when they can be proven to always execute:
```asm
start_first:
  mov 2, %l3
  set 0xFFFF, %l0

  cmp %l0, %i1
  bge start_third
  nop
```
->
```asm
start_first:
   set  0xFFFF,   %l0
   cmp  %l0,  %i1
   bge  start_third
   mov  2,  %l3
```

----

##### Following data dependencies to find an indepdenent 'mov' instruction:
```asm
start_second:
  mov 5, %l2
  mov %l0, %l1
  cmp %l1, %g0
  ble endinner
  nop
```
->
```asm
start_second:
  mov  %l0,  %l1
  cmp  %l1,  %g0
  ble  endinner
  mov  5,  %l2
```

----

##### Filling the delay slot of an instruction that depends on a side effect
of the delay slot instruction:
```asm
start_third:
  mov %l1, %o0
  mov 4, %o1
  call  .mul
  nop
```
->
```asm
start_third:
  mov  %l1,  %o0
  call   .mul
  mov  4,  %o1
```

----

##### Reordering independent instructions across a compare
```asm
start_fourth:
  mov %o0, %l2
  add %i0, %l2, %l2

  cmp %l3, %l4
  bge start_routine
  nop
```

->
```asm
start_fourth:
  mov  %o0,  %l2
  cmp  %l3,  %l4
  bge  start_routine
  add  %i0,  %l2,  %l2
```


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
