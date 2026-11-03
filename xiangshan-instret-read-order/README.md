# XiangShan: csrr of minstret/instret is not ordered after older instructions

For [OpenXiangShan/XiangShan#ISSUE](https://github.com/OpenXiangShan/XiangShan/issues/ISSUE).

`instret.S` reads `minstret` (or `instret`), runs 8 instructions, and reads it again, 4 times per
case. The difference must be 9: the first `csrr` and the 8 instructions after it. Zicsr says "an
explicit CSR read returns the CSR state before the execution of the instruction", and a CSR access
is performed after all prior instructions that modify that CSR.

- `make` builds `instret.elf` (XiangShan: UART-lite output, good/bad trap) and `instret-sail.elf`
  (`-DSAIL`, ends through tohost). Prebuilt ELFs and `instret.dump` are included.
- `run.sh` runs both. Set `XIANGSHAN_EMU` to an emulator built with `CONFIG=KunminghuV2Config`.
- `observed-xiangshan.txt` is the emulator output at e7bab53e66 (kunminghu-v2). On Sail 0.16 with
  `sail.json` every difference is 9.

| Case | 8 instructions between the reads | XiangShan differences (required 9 each) |
|---|---|---|
| A | independent `addi`, `minstret` | 5 0 0 0 |
| B | independent `addi`, `instret` | 5 0 0 0 |
| C | dependent `mul` chain | 5 5 0 34 |
| D | `ld` and 7 instructions that use it | 0 0 0 0 |
| E | 2 `div` and 6 `addi` | 0 0 0 0 |
