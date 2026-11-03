# XiangShan: a load/store trigger on a vector element writes the wrong mtval.
# Bare-metal M-mode program for the XiangShan difftest emulator (UART-lite TX at 0x40600004,
# good/bad trap = custom instruction 0x0005006b with a0 = 0/1). Build with -DSAIL to run it on
# the Sail model instead (no UART output; ends by writing tohost).
#
# Each case arms trigger 0 as mcontrol6 (type 6, m = 1, match = 0 equal, size = 0 any,
# select = 0 address, action = 0 breakpoint) on tdata2 = buf + OFF, runs one access, and the
# breakpoint handler records mcause, mtval - buf and vstart. The Sdtrig spec says a vector
# access is matched "as if [the element accesses] all happened individually" and mtval is
# "the address being accessed and which caused that trigger to fire", so mtval must be
# buf + OFF, and vstart the index of that element.

#define TDATA1_LOAD  0x6000000000000041   /* type 6, m, load */
#define TDATA1_STORE 0x6000000000000042   /* type 6, m, store */

  .section .text.init
  .globl _start
_start:
  la    t0, handler
  csrw  mtvec, t0
  csrw  mie, zero
  li    t0, 0x200            # mstatus.VS = Initial
  csrs  mstatus, t0
  li    t0, 1 << 42          # mstatus.MDT = 0 (Sail resets it to 1; XiangShan's boot flash clears it)
  csrc  mstatus, t0
  csrsi mstatus, 0x8         # MIE = 1: triggers with action = 0 fire in M-mode only then
  li    s0, 0                # number of failing cases
  csrw  tselect, zero
  la    sp, stack_top

# CASE name, tdata1, offset of tdata2 from buf, expected vstart, setup, access
.macro CASE name, td1, off, evstart, setup, access
  la    a0, str_\name
  call  puts
  la    t0, res
  li    t1, -1
  sd    t1, 0(t0)            # mcause = -1 means no trap
  sd    t1, 8(t0)
  sd    t1, 16(t0)
  csrw  tdata1, zero
  la    t0, buf
  addi  t0, t0, \off
  csrw  tdata2, t0
  li    t0, \td1
  csrw  tdata1, t0
  la    a5, buf
  \setup
  \access
  nop
  csrw  tdata1, zero
  li    a1, \off
  li    a2, \evstart
  call  report
.endm

  # A: control. vl = 9, trigger on element 0
  CASE a, TDATA1_LOAD, 0, 0, "vsetivli x0, 9, e8, m4, ta, ma", "vle8.v v8, (a5)"
  # B: vl = 9, trigger on element 8 (the failing ACT case)
  CASE b, TDATA1_LOAD, 8, 8, "vsetivli x0, 9, e8, m4, ta, ma", "vle8.v v8, (a5)"
  # C: vl = 32, trigger on element 24 (second 16-byte flow)
  CASE c, TDATA1_LOAD, 24, 24, "li t0, 32; vsetvli x0, t0, e8, m4, ta, ma", "vle8.v v8, (a5)"
  # D: masked, elements 0-3 inactive, trigger on element 8
  CASE d, TDATA1_LOAD, 8, 8, "vsetivli x0, 16, e16, m1, ta, mu; li t0, 0xfff0; vmv.s.x v0, t0; vsetivli x0, 9, e8, m4, ta, mu", "vle8.v v8, (a5), v0.t"
  # E: e32, vl = 4, trigger on element 2
  CASE e, TDATA1_LOAD, 8, 2, "vsetivli x0, 4, e32, m4, ta, ma", "vle32.v v8, (a5)"
  # F: store, vl = 9, trigger on element 8
  CASE f, TDATA1_STORE, 8, 8, "vsetivli x0, 9, e8, m4, ta, ma", "vse8.v v8, (a5)"
  # G: scalar control, lb at buf + 8
  CASE g, TDATA1_LOAD, 8, 0, "csrw vstart, zero", "lb t2, 8(a5)"

  csrci mstatus, 0x8
#ifdef SAIL
  la    t0, tohost
  li    t1, 1
  bnez  s0, 1f
  sd    t1, 0(t0)
1:li    t1, 3
  sd    t1, 0(t0)
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

# Breakpoint handler: record mcause, mtval - buf, vstart; disarm; skip the instruction.
  .balign 4
handler:
  csrw  mscratch, t0
  la    t0, res
  sd    t1, 24(t0)
  csrr  t1, mcause
  sd    t1, 0(t0)
  csrr  t1, mtval
  sd    t1, 8(t0)
  csrr  t1, vstart
  sd    t1, 16(t0)
  csrw  tdata1, zero
  csrw  vstart, zero
  csrr  t1, mepc
  addi  t1, t1, 4
  csrw  mepc, t1
  ld    t1, 24(t0)
  csrr  t0, mscratch
  mret

# report(a1 = expected offset, a2 = expected vstart): print the result, count a mismatch
report:
  addi  sp, sp, -16
  sd    ra, 0(sp)
  la    t3, res
  ld    t4, 8(t3)
  la    t5, buf
  sub   t4, t4, t5
  sd    t4, 8(t3)          # mtval - buf
  la    a0, str_mcause
  call  puts
  ld    a0, 0(t3)
  call  puthex
  la    a0, str_mtval
  call  puts
  ld    a0, 8(t3)
  call  puthex
  la    a0, str_vstart
  call  puts
  ld    a0, 16(t3)
  call  puthex
  la    a0, str_expect
  call  puts
  mv    a0, a1
  call  puthex
  la    a0, str_vstart
  call  puts
  mv    a0, a2
  call  puthex
  ld    t4, 0(t3)
  li    t5, 3
  bne   t4, t5, 1f
  ld    t4, 8(t3)
  bne   t4, a1, 1f
  ld    t4, 16(t3)
  bne   t4, a2, 1f
  la    a0, str_ok
  j     2f
1:addi  s0, s0, 1
  la    a0, str_bad
2:call  puts
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
str_a:      .asciz "A  vle8.v        vl=9  e8,  tdata2=buf+0x0  : "
str_b:      .asciz "B  vle8.v        vl=9  e8,  tdata2=buf+0x8  : "
str_c:      .asciz "C  vle8.v        vl=32 e8,  tdata2=buf+0x18 : "
str_d:      .asciz "D  vle8.v v0.t   vl=9  e8,  elements 0-3 inactive, tdata2=buf+0x8 : "
str_e:      .asciz "E  vle32.v       vl=4  e32, tdata2=buf+0x8  : "
str_f:      .asciz "F  vse8.v        vl=9  e8,  tdata2=buf+0x8  : "
str_g:      .asciz "G  lb (scalar)              tdata2=buf+0x8  : "
str_mcause: .asciz "mcause="
str_mtval:  .asciz " mtval=buf+"
str_vstart: .asciz " vstart="
str_expect: .asciz "  (required: mcause=0x3 mtval=buf+"
str_ok:     .asciz ")  ok\n"
str_bad:    .asciz ")  WRONG\n"
str_pass:   .asciz "PASS\n"
str_fail:   .asciz "FAIL\n"

  .data
  .balign 64
buf:    .fill 64, 1, 0x5a
  .balign 8
res:    .dword 0, 0, 0, 0
  .balign 4096
  .space 4096
stack_top:
  .balign 64
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
