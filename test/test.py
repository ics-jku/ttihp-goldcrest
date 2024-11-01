# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotbext.spi import SpiBus

from spi_imem import SpiIMem


#@cocotb.test()
async def test_project(dut, program, cycles, test):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 50, units="ns")
    cocotb.start_soon(clock.start())

    spi_bus = SpiBus.from_prefix(dut, "spi")
    spi_imem = SpiIMem(spi_bus, program)

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    await ClockCycles(dut.clk, cycles)
    assert(test(dut))

@cocotb.test()
async def test_gpio(dut):
   await test_project(dut, "sw/gpio.hex", 800, lambda dut: dut.uio_out.value[0:3].integer == 0b1111)

# @cocotb.test()
# async def test_coproc(dut):
#    await test_project(dut, "sw/coproc.hex", 1800, lambda dut: dut.uio_out.value[0:3].integer == 0b0001)
