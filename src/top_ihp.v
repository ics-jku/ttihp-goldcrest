/*
 * Copyright (c) 2022 Lucas Klemmer
 * Copyright (c) 2022 Felix Roithmayr
 * SPDX-License-Identifier: Apache-2.0
 */

`ifndef __TOP_IHP__
`define __TOP_IHP__
`include "wb_emem.v"
`include "wb_imem.v"
`include "wb_gpio.v"
`include "wb_spi.v"
`include "wb_uart.v"
`include "wb_oisc.v"
//`include "wb_coproc.v"

`define SPI_RAM_BIT 31
`define SPI_ROM_BIT 30
`define UART_BIT 29
`define GPIO_BIT 28
//`define COPROC_BIT 27
`define SPI_BIT 26

module top_ihp(
              input wire        clk,
              input wire        rst_n,
              // UART
              output wire       tx,
              input wire        rx,
              // ROM
              input wire        rom_data_i,
              output wire       rom_clk_o,
              output wire       rom_cs_o,
              output wire       rom_data_o,
              // RAM
              input wire        ram_data_i,
              output wire       ram_clk_o,
              output wire       ram_cs_o,
              output wire       ram_data_o,
              // SPI
              input wire        spi_data_i,
              output wire       spi_clk_o,
              output wire       spi_cs_o_1,
              output wire       spi_cs_o_2,
              output wire       spi_cs_o_3,
              output wire       spi_data_o,
              // GPIO
              input wire        gpio_i_1,
              input wire        gpio_i_2,
              input wire        gpio_i_3,
              input wire        gpio_i_4,
              output wire       gpio_o_1,
              output wire       gpio_o_2,
              output wire       gpio_o_3,
              output wire       gpio_o_4
              );

   wire                         wb_ack;
   wire [31:0]                  wb_dati;
   wire                         wb_cyc;
   wire [3:0]                   wb_sel;
   wire                         wb_stb;
   wire                         wb_we;
   wire [31:0]                  wb_dato;
   wire [31:0]                  wb_adr;
   wire [3:0]                   gpio_i;
   wire [3:0]                   gpio_o;

   assign gpio_i = {gpio_i_4, gpio_i_3, gpio_i_2, gpio_i_1};
   assign gpio_o_1 = gpio_o[0];
   assign gpio_o_2 = gpio_o[1];
   assign gpio_o_3 = gpio_o[2];
   assign gpio_o_4 = gpio_o[3];

   // Memory Map
   // 1000000000000000_0000000000000000 SPI_RAM (0x80000000)
   // 0100000000000000_0000000000000000 SPI_ROM (0x40000000)
   // 0010000000000000_0000000000000000 UART    (0x20000000)
   // 0001000000000000_0000000000000000 GPIO    (0x10000000)
   // 0000100000000000_0000000000000000 COPROC  (0x08000000)
   // 0000010000000000_0000000000000000 SPI     (0x04000000)

   wb_oisc oisc(.clk(clk),
		.rst_n(rst_n),
                .wb_ack_i(wb_ack),
                .wb_dat_i(wb_dati),
                .wb_cyc_o(wb_cyc),
                .wb_stb_o(wb_stb),
                .wb_sel_o(wb_sel),
                .wb_we_o(wb_we),
                .wb_dat_o(wb_dato),
                .wb_adr_o(wb_adr));

   wire                         wb_cyc_ram = wb_cyc & wb_adr[`SPI_RAM_BIT];
   wire                         wb_cyc_rom = wb_cyc & wb_adr[`SPI_ROM_BIT];
   wire                         wb_cyc_uart = wb_cyc & wb_adr[`UART_BIT];
   wire                         wb_cyc_gpio = wb_cyc & wb_adr[`GPIO_BIT];
   wire                         wb_cyc_spi = wb_cyc & wb_adr[`SPI_BIT];
   // wire                         wb_cyc_coproc = wb_cyc & wb_adr[`COPROC_BIT];

   wire                         wb_ack_gpio;
   wire                         wb_ack_uart;
   wire                         wb_ack_rom;
   wire                         wb_ack_ram;
   wire                         wb_ack_spi;
   // wire                         wb_ack_coproc;

   wire [31:0]                  wb_dati_uart;
   wire [31:0]                  wb_dati_gpio;
   wire [31:0]                  wb_dati_rom;
   wire [31:0]                  wb_dati_ram;
   wire [31:0]                  wb_dati_spi;
   // wire [31:0]                  wb_dati_coproc;

   assign      wb_ack = wb_ack_uart |
                        wb_ack_gpio |
                        wb_ack_rom  |
                        wb_ack_ram  |
                        wb_ack_spi;
                        // || wb_ack_coproc;
   assign      wb_dati = wb_ack_uart ? wb_dati_uart :
                         wb_ack_gpio ? wb_dati_gpio :
                         wb_ack_rom ? wb_dati_rom : 
                         wb_ack_ram ? wb_dati_ram : 
                         wb_ack_spi ? wb_dati_spi : 0;
                         //wb_ack_coproc ? wb_dati_coproc :
                         //0;

   wb_uart wb_uart(.clk(clk),
                   .rst_n(rst_n),
                   .adr_i(wb_adr[15:0]),
                   .dat_i(wb_dato),
                   .we_i(wb_we),
                   .sel_i(wb_sel),
                   .stb_i(wb_stb),
                   .cyc_i(wb_cyc_uart),
                   .ack_o(wb_ack_uart),
                   .dat_o(wb_dati_uart),
                   .tx(tx),
                   .rx(rx));

   wb_imem wb_imem(.clk(clk),
                   .rst_n(rst_n),
                   .adr_i(wb_adr),
                   .dat_i(wb_dato),
                   .dat_o(wb_dati_rom),
                   .we_i(wb_we),
                   .sel_i(wb_sel),
                   .stb_i(wb_stb),
                   .ack_o(wb_ack_rom),
                   .cyc_i(wb_cyc_rom),
                   // SPI signals
                   .spi_data_i(rom_data_i),
                   .spi_clk_o(rom_clk_o),
                   .spi_cs_o(rom_cs_o),
                   .spi_data_o(rom_data_o)
                   );


   wb_emem wb_emem(.clk(clk),
                   .rst_n(rst_n),
                   .adr_i(wb_adr),
                   .dat_i(wb_dato),
                   .dat_o(wb_dati_ram),
                   .we_i(wb_we),
                   .sel_i(wb_sel),
                   .stb_i(wb_stb),
                   .ack_o(wb_ack_ram),
                   .cyc_i(wb_cyc_ram),
                   // SPI signals
                   .spi_data_i(ram_data_i),
                   .spi_clk_o(ram_clk_o),
                   .spi_cs_o(ram_cs_o),
                   .spi_data_o(ram_data_o)
                   );

   wb_spi wb_spi(.clk(clk),
                   .rst_n(rst_n),
                   .adr_i(wb_adr),
                   .dat_i(wb_dato),
                   .dat_o(wb_dati_spi),
                   .we_i(wb_we),
                   .sel_i(wb_sel),
                   .stb_i(wb_stb),
                   .ack_o(wb_ack_spi),
                   .cyc_i(wb_cyc_spi),
                   // SPI signals
                   .spi_data_i(spi_data_i),
                   .spi_clk_o(spi_clk_o),
                   .spi_cs_o_1(spi_cs_o_1),
                   .spi_cs_o_2(spi_cs_o_2),
                   .spi_cs_o_3(spi_cs_o_3),
                   .spi_data_o(spi_data_o)
                   );

   wb_gpio wb_gpio(
               .clk(clk),
               .rst_n(rst_n),
               .adr_i(wb_adr), // ADR_I() address
               .dat_i(wb_dato), // DAT_I() data in
               .dat_o(wb_dati_gpio), // DAT_O() data out
               .we_i(wb_we), // WE_I write enable input
               .sel_i(wb_sel), // SEL_I() select input
               .stb_i(wb_stb), // STB_I strobe input
               .ack_o(wb_ack_gpio), // ACK_O acknowledge output
               .cyc_i(wb_cyc_gpio), // CYC_I cycle input,
               .gpio_i(gpio_i),
               .gpio_o(gpio_o)
               );

   // wb_coproc wb_coproc(.clk(clk),
   //            .rst_n(rst_n),
   //            .adr_i(wb_adr[4:0]),
   //            .dat_i(wb_dato),
   //            .dat_o(wb_dati_coproc),
   //            .we_i(wb_we),
   //            .stb_i(wb_stb),
   //            .ack_o(wb_ack_coproc),
   //            .cyc_i(wb_cyc_coproc));

endmodule
`endif
