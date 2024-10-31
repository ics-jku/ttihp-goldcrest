main:
	li s0, 0x10000000 
	li t0, 1
	
	sw t0, 0(s0)
	sw t0, 1(s0)
	sw t0, 2(s0)
	sw t0, 3(s0)

loop:
	j loop
