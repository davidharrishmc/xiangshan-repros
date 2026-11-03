# XiangShan: a trigger on a vector element writes the flow's first active byte to mtval

For [OpenXiangShan/XiangShan#6851](https://github.com/OpenXiangShan/XiangShan/issues/6851).

`vtrig.S` arms trigger 0 as mcontrol6 (type 6, m = 1, match = equal, size = any, select = address,
action = breakpoint) on `tdata2 = buf + OFF`. It then runs one vector load or store that reaches
that byte. The breakpoint handler records mcause, mtval - buf and vstart. Cases A and G are
controls: element 0, and a scalar `lb`.

- `make` builds `vtrig.elf` (XiangShan: UART-lite output, good/bad trap) and `vtrig-sail.elf`
  (`-DSAIL`: no output, ends through tohost). Prebuilt ELFs and `vtrig.dump` are included.
- `run.sh` runs both. Set `XIANGSHAN_EMU` to an emulator built with `CONFIG=KunminghuV2Config`.
- `observed-xiangshan.txt` is the emulator output at e7bab53e66 (kunminghu-v2).
- `sail.json` is the riscv-arch-test configuration for KunminghuV2. On Sail 0.16 every case
  passes, with mtval = buf + OFF.

| Case | Access | tdata2 | Required mtval, vstart | XiangShan mtval, vstart |
|---|---|---|---|---|
| A | `vle8.v`, vl = 9 | buf+0x0 | buf+0x0, 0 | buf+0x0, 0 |
| B | `vle8.v`, vl = 9 | buf+0x8 | buf+0x8, 8 | **buf+0x0**, 8 |
| C | `vle8.v`, vl = 32 | buf+0x18 | buf+0x18, 24 | **buf+0x10**, 24 |
| D | `vle8.v v0.t`, vl = 9, elements 0-3 inactive | buf+0x8 | buf+0x8, 8 | **buf+0x4**, 8 |
| E | `vle32.v`, vl = 4 | buf+0x8 | buf+0x8, 2 | **buf+0x0**, 2 |
| F | `vse8.v`, vl = 9 | buf+0x8 | buf+0x8, 8 | **buf+0x0**, 8 |
| G | `lb` | buf+0x8 | buf+0x8, 0 | buf+0x8, 0 |
