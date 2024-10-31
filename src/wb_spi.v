/*
 * Copyright (c) 2022 Lucas Klemmer
 * Copyright (c) 2022 Felix Roithmayr
 * SPDX-License-Identifier: Apache-2.0
 */

`ifndef __WB_SPI__
`define __WB_SPI__
`define SPI_1_BIT 4
`define SPI_2_BIT 5
`define SPI_3_BIT 6

module wb_spi(
               input wire         clk,
               input wire         rst_n,
               // Wishbone signals
               input wire [31:0]  adr_i, // ADR_I() address
               input wire [31:0]  dat_i, // DAT_I() data in
               input wire         we_i, // WE_I write enable input
               input wire [3:0]   sel_i, // SEL_I() select input
               input wire         stb_i, // STB_I strobe input
               input wire         cyc_i, // CYC_I cycle input,
               output reg         ack_o, // ACK_O acknowledge output
               output wire [31:0] dat_o, // DAT_O() data out
               // SPI signals
               input wire         spi_data_i,
               output wire        spi_clk_o,
               output reg         spi_cs_o_1,
               output reg         spi_cs_o_2,
               output reg         spi_cs_o_3,
               output wire        spi_data_o
               );

   /* verilator lint_off UNUSEDSIGNAL */
   wire [31:7] dummy1;
   assign dummy1 = adr_i[31:7];
   wire [3:0] dummy2;
   assign dummy2 = adr_i[3:0];
   /* verilator lint_on UNUSEDSIGNAL */

   localparam                     S_IDLE = 0;
   localparam                     S_SENDING = 1;

   reg                            state;
   reg [5:0]                      bits_left;
   reg [31:0]                     cmd;

   // generate slower 10Mhz SPI clock to make led matrix work
   reg [1:0] spi_clk_cnt;
   wire      spi_clk = spi_clk_cnt[1];
   always @(negedge clk or negedge rst_n) 
      if (!rst_n) begin
         spi_clk_cnt <= 0;   
      end else begin
         spi_clk_cnt <= spi_clk_cnt + 2'd1;
      end

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         state <= S_IDLE;
         bits_left <= 0;
         spi_cs_o_1 <= 1;
         spi_cs_o_2 <= 1;
         spi_cs_o_3 <= 1;
         ack_o <= 0;
         cmd <= 0;
      end else begin
         ack_o <= 0;
         case (state)
           S_IDLE: begin
              if (stb_i & cyc_i) begin
                 if (we_i) begin
                    state <= S_SENDING;
                    bits_left <= sel_i == 4'b1111 ? 6'd32:
                                 sel_i == 4'b0011 ? 6'd16:
                                 sel_i == 4'b0001 ? 6'd8 : 6'd0;
                    spi_cs_o_1 <= adr_i[`SPI_1_BIT];
                    spi_cs_o_2 <= adr_i[`SPI_2_BIT];
                    spi_cs_o_3 <= adr_i[`SPI_3_BIT];
                    cmd <= sel_i == 4'b1111 ? dat_i :
                           sel_i == 4'b0011 ? {dat_i[15:0], 16'b0} :
                           sel_i == 4'b0001 ? {dat_i[7:0], 24'b0} : 32'd0;
                 end else begin
                    ack_o <= 1;
                 end
              end
           end
           S_SENDING: begin
              if (spi_clk_cnt == 2'b10) begin
               cmd <= {cmd[30:0], spi_data_i};
               bits_left <= bits_left - 6'd1;
               if (bits_left == 1) begin
                  state <= S_IDLE;
                  bits_left <= 6'd0;
                  spi_cs_o_1 <= 1;
                  spi_cs_o_2 <= 1;
                  spi_cs_o_3 <= 1;
                  ack_o <= 1;
               end
              end
           end
         endcase
      end
   end // always @ (negedge clk)

   assign dat_o =  cmd;
   assign spi_clk_o = spi_clk;
   assign spi_data_o = (state == S_SENDING) ? cmd[31] : 1'b0;

endmodule
`endif
