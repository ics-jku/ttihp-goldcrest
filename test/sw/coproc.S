main:
	li a0, 0x08000000 # coproc
	li a1, 0x10000000 # gpio 
	# reset gpio pin 0
	sw x0, 0(a1)
	sw x0, 1(a1)
	sw x0, 2(a1)
	sw x0, 3(a1)

	li a2, 0b1
	li a3, 0b1

	# send to coproc
	sw a2, 0(a0)
	sw a3, 4(a0)
	# read results
	lw t0, 12(a0) # a & b
	# write to gpio bit 0
	sw t0, 0(a1)

loop:
	j loop
