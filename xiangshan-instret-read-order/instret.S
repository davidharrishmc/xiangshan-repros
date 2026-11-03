# XiangShan: csrr of minstret/instret is not ordered after older instructions.
# Bare-metal M-mode program for the XiangShan difftest emulator (UART-lite TX at 0x40600004,
# good/bad trap = custom instruction 0x0005006b with a0 = 0/1). Build with -DSAIL for Sail.
#
# Each case reads the counter, runs 8 more instructions, and reads it again. An explicit CSR
# read "returns the CSR state before the execution of the instruction" and is performed after
# all prior instructions (Zicsr, CSR Access Ordering), so the difference must be 9: the first
# csrr and the 8 instructions after it. Each case runs 4 times.

  .section .text.init
  .globl _start
_start:
  la    sp, stack_top
  li    s0, 0                # number of wrong differences
  csrw  mcountinhibit, zero
  la    s2, buf

.macro CASE name, csr, b1, b2, b3, b4, b5, b6, b7, b8
  la    a0, str_\name
  call  puts
  li    s1, 4
1:
  csrr  a3, \csr
  \b1
  \b2
  \b3
  \b4
  \b5
  \b6
  \b7
  \b8
  csrr  a4, \csr
  sub   a0, a4, a3
  call  check
  addi  s1, s1, -1
  bnez  s1, 1b
  la    a0, str_nl
  call  puts
.endm

  # A: 8 independent addi
  CASE a, minstret, "addi t0, t0, 1", "addi t1, t1, 1", "addi t2, t2, 1", "addi t3, t3, 1", "addi t4, t4, 1", "addi t5, t5, 1", "addi a5, a5, 1", "addi a6, a6, 1"
  # B: the same, reading the user-level instret
  CASE b, instret, "addi t0, t0, 1", "addi t1, t1, 1", "addi t2, t2, 1", "addi t3, t3, 1", "addi t4, t4, 1", "addi t5, t5, 1", "addi a5, a5, 1", "addi a6, a6, 1"
  # C: a dependent chain of 8 multiplies
  CASE c, minstret, "mul t0, t0, t0", "mul t0, t0, t0", "mul t0, t0, t0", "mul t0, t0, t0", "mul t0, t0, t0", "mul t0, t0, t0", "mul t0, t0, t0", "mul t0, t0, t0"
  # D: a load and 7 instructions that use it
  CASE d, minstret, "ld t0, 0(s2)", "add t1, t0, t0", "add t1, t1, t0", "add t1, t1, t0", "add t1, t1, t0", "add t1, t1, t0", "add t1, t1, t0", "sd t1, 8(s2)"
  # E: two divides and 6 addi
  CASE e, minstret, "div t0, s2, s1", "div t1, t0, s1", "addi t2, t2, 1", "addi t3, t3, 1", "addi t4, t4, 1", "addi t5, t5, 1", "addi a5, a5, 1", "addi a6, a6, 1"

#ifdef SAIL
  la    t0, tohost
  li    t1, 1
  beqz  s0, 1f
  li    t1, 3
1:sd    t1, 0(t0)
2:j     2b
#else
  la    a0, str_pass
  beqz  s0, 1f
  la    a0, str_fail
1:call  puts
  snez  a0, s0
  .word 0x0005006b
3:j     3b
#endif

# check(a0 = difference): print it, count it if it isn't 9
check:
  addi  sp, sp, -16
  sd    ra, 0(sp)
  li    t6, 9
  beq   a0, t6, 1f
  addi  s0, s0, 1
1:call  puthex
  la    a0, str_sp
  call  puts
  ld    ra, 0(sp)
  addi  sp, sp, 16
  ret

# puts(a0 = string)
puts:
#ifndef SAIL
  li    t6, 0x40600004
1:lbu   t2, 0(a0)
  beqz  t2, 2f
  sb    t2, 0(t6)
  addi  a0, a0, 1
  j     1b
2:
#endif
  ret

# puthex(a0): "0x" and the value in hex without leading zeros (-1 printed as "-1")
puthex:
#ifndef SAIL
  li    t6, 0x40600004
  li    t2, -1
  bne   a0, t2, 1f
  li    t2, '-'
  sb    t2, 0(t6)
  li    t2, '1'
  sb    t2, 0(t6)
  ret
1:li    t2, '0'
  sb    t2, 0(t6)
  li    t2, 'x'
  sb    t2, 0(t6)
  li    t0, 60
  li    t1, 0              # 1 once a nonzero digit has been printed
2:srl   t2, a0, t0
  andi  t2, t2, 0xf
  or    t1, t1, t2
  bnez  t0, 3f
  li    t1, 1
3:beqz  t1, 5f
  addi  t2, t2, '0'
  li    t5, '9'
  ble   t2, t5, 4f
  addi  t2, t2, 'a' - '9' - 1
4:sb    t2, 0(t6)
5:addi  t0, t0, -4
  bgez  t0, 2b
#endif
  ret

  .section .rodata
str_a:    .asciz "A  minstret, 8 addi        (required 0x9 each): "
str_b:    .asciz "B  instret,  8 addi        (required 0x9 each): "
str_c:    .asciz "C  minstret, 8 mul chain   (required 0x9 each): "
str_d:    .asciz "D  minstret, ld + 7 users  (required 0x9 each): "
str_e:    .asciz "E  minstret, 2 div + 6 addi (required 0x9 each): "
str_sp:   .asciz " "
str_nl:   .asciz "\n"
str_pass: .asciz "PASS\n"
str_fail: .asciz "FAIL\n"

  .data
  .balign 64
buf:    .dword 3, 0
  .balign 4096
  .space 4096
stack_top:
  .balign 64
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
