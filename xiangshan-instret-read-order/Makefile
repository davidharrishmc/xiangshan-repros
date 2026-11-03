RVCC ?= riscv64-unknown-elf-gcc
FLAGS = -march=rv64gc_zicsr_zicntr -mabi=lp64 -nostdlib -nostartfiles -static -T link.ld
all: instret.elf instret-sail.elf
instret.elf: instret.S link.ld
	$(RVCC) $(FLAGS) -o $@ instret.S
	riscv64-unknown-elf-objdump -d $@ > instret.dump
instret-sail.elf: instret.S link.ld
	$(RVCC) $(FLAGS) -DSAIL -o $@ instret.S
clean:
	rm -f *.elf instret.dump
