SRCS=$(wildcard *.S)
HEX=$(SRCS:.S=.hex)

all: $(HEX)

%.hex: %.S
	riscv32-unknown-elf-as $< -o a.out
	riscv32-unknown-elf-objcopy -O binary -j .text -j .rodata a.out a.bin 
	xxd -c 4 a.bin | awk '{print $$2$$3}' > $@
	rm a.*

clean:
	rm *.hex
