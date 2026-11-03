RVCC ?= riscv64-unknown-elf-gcc
FLAGS = -march=rv64gcv_zicsr -mabi=lp64 -nostdlib -nostartfiles -static -T link.ld
all: vtrig.elf vtrig-sail.elf
vtrig.elf: vtrig.S link.ld
	$(RVCC) $(FLAGS) -o $@ vtrig.S
	riscv64-unknown-elf-objdump -d $@ > vtrig.dump
vtrig-sail.elf: vtrig.S link.ld
	$(RVCC) $(FLAGS) -DSAIL -o $@ vtrig.S
clean:
	rm -f *.elf vtrig.dump
