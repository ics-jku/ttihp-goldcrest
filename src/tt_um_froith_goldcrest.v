/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_froith_goldcrest (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  top_ihp top_ihp(
              .clk(clk),
              .reset(~rst_n),
              // UART
              .tx(uo_out[0]),
              .rx(ui_in[0]),
              // ROM
              .rom_data_i(ui_in[1]),
              .rom_clk_o(uo_out[1]),
              .rom_data_o(uo_out[2]),
              .rom_cs_o(uo_out[3]),
              // RAM
              .ram_data_i(ui_in[2]),
              .ram_clk_o(uo_out[4]),
              .ram_data_o(uo_out[5]),
              .ram_cs_o(uo_out[6]),
              // SPI
              .spi_data_i(ui_in[3]),
              .spi_clk_o(uo_out[7]),
              .spi_data_o(uio_out[0]),
              .spi_cs_o_1(uio_out[1]),
              .spi_cs_o_2(uio_out[2]),
              .spi_cs_o_3(uio_out[3]),
              // UART
              .gpio_i_1(ui_in[4]),
              .gpio_i_2(ui_in[5]),
              .gpio_i_3(ui_in[6]),
              .gpio_i_4(ui_in[7]),
              .gpio_o_1(uio_out[4]),
              .gpio_o_2(uio_out[5]),
              .gpio_o_3(uio_out[6]),
              .gpio_o_4(uio_out[7])
              );

  assign uio_oe  = 8'b11111111;

  // List all unused inputs to prevent warnings
  wire _unused = &{uio_in, ena, 1'b0};

endmodule
