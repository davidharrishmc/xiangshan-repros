#!/usr/bin/env bash
# Run the reproducer on the XiangShan difftest emulator (no reference model) and, if
# sail_riscv_sim is on PATH, on the Sail model.
#   XIANGSHAN_EMU: emulator built with CONFIG=KunminghuV2Config (default ./emu)
set -u
cd "$(dirname "$0")"
EMU="${XIANGSHAN_EMU:-./emu}"
"$EMU" -i vtrig.elf --no-diff -C 2000000 2>&1 | grep -a -v '^\[PERF'
if command -v sail_riscv_sim >/dev/null; then
  sail_riscv_sim --config sail.json --trace --trace-output sail.trace vtrig-sail.elf | tail -1
  grep -E 'CSR (mcause|mtval) \(0x34[23]\) <-' sail.trace
fi
