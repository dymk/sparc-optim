  .section  ".text"
  .global start_routine

start_first:
  mov 2, %l3
  set 0xFFFF, %l0

  cmp %l0, %i1
  bge start_third
  nop


start_second:
  mov 5, %l2
  mov %l0, %l1
  cmp %l1, %g0
  ble endinner
  nop


start_third:
  mov %l1, %o0
  mov 4, %o1
  call  .mul
  nop

start_fourth:
  mov %o0, %l2
  add %i0, %l2, %l2

  cmp %l3, %l4
  bge start_routine
  nop

start_fifth:
  mov  %l0,  %l1
  cmp  %l1,  %g0
  ble,a  endinner
  mov  5,  %l2
