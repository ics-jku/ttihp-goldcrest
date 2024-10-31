/*
 * spi_flash_reader.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
 * Copyright (C) 2024  Felix Roithmayr <felix.roithmayr@jku.at>
 * All rights reserved.
 *
 * BSD 3-clause, see LICENSE.bsd
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

`ifndef __WB_EMEM__
`define __WB_EMEM__

// This is based on Sylvain Munaut's spi flash reader.
// https://github.com/smunaut/ice40-playground/blob/d2fa0050129c14a7fc42f64f115366f6f2a51669/cores/spi_flash/rtl/spi_flash_reader.v
module wb_emem(
               input wire         clk,
               input wire         rst_n,
               // Wishbone signals
               input wire [31:0]  adr_i, // ADR_I() address
               input wire [31:0]  dat_i, // DAT_I() data in
               input wire         we_i, // WE_I write enable input
               input wire [3:0]   sel_i, // SEL_I() select input
               input wire         stb_i, // STB_I strobe input
               input wire         cyc_i, // CYC_I cycle input,
               output wire        ack_o, // ACK_O acknowledge output
               output wire [31:0] dat_o, // DAT_O() data out
               // SPI signals
               input wire         spi_data_i,
               output wire        spi_clk_o,
               output wire         spi_cs_o,
               output wire        spi_data_o
               );

   /* verilator lint_off UNUSEDSIGNAL */
   wire [31:24] dummy1;
   assign dummy1 = adr_i[31:24];
   /* verilator lint_on UNUSEDSIGNAL */

	// FSM
	localparam
		S_STARTUP 	    = 4'b0000,
      S_SEND_RSTEN    = 4'b1100,
      S_DELAY_RSTEN   = 4'b1000,
      S_WAIT_RSTEN    = 4'b0001,
      S_SEND_RST      = 4'b1101,
      S_DELAY_RST     = 4'b1001,
      S_WAIT_RST      = 4'b0010,
      S_IDLE          = 4'b0011,
      S_SEND_BYTE     = 4'b1110,
      S_DELAY         = 4'b1010;
      

   localparam
      BYTE = 8,
      HALF = 16,
      WORD = 32;

	reg [3:0] state;
	reg [3:0] state_next;


	// Counters
	reg [7:0] bit_counter;
   reg [7:0] wait_counter;
   reg [7:0] nbits;
	reg last_bit;
   reg last_wait;

	reg [63:0] cmd;

	// Misc

	// FSM
	// ---

	// State register
	always @(negedge clk or negedge rst_n)
		if (!rst_n)
			state <= S_STARTUP;
		else
			state <= state_next;

	// Next-State logic
	always @(*)
	begin
		// Default is not to move
		state_next = state;

		// Transitions ?
		case (state)
         S_STARTUP: begin
            state_next = S_SEND_RSTEN;
         end
         S_SEND_RSTEN: begin
            if (last_bit)
               state_next = S_DELAY_RSTEN;
         end
         S_DELAY_RSTEN: begin
            state_next = S_WAIT_RSTEN;
         end
         S_WAIT_RSTEN: begin
            if (last_wait)
               state_next = S_SEND_RST;
         end
         S_SEND_RST: begin
            if (last_bit)
               state_next = S_DELAY_RST;
         end
         S_DELAY_RST: begin
            state_next = S_WAIT_RST;
         end
         S_WAIT_RST: begin
            if (last_wait)
               state_next = S_IDLE;
         end
         S_IDLE: begin
            if (stb_i & cyc_i)
               state_next = S_SEND_BYTE;
         end
         S_SEND_BYTE: begin
            if (last_bit)
               state_next = S_DELAY;
         end
         S_DELAY: begin
            state_next = S_IDLE;
         end
         default: begin

         end
		endcase
	end


	// Shift Register
	// --------------

	always @(negedge clk or negedge rst_n)
		if (!rst_n)
			cmd <= 64'h6699000000000000;
		else begin
         if (state == S_STARTUP) 
            nbits <= 8;
         else if (state == S_WAIT_RSTEN)
            nbits <= 8;
         else if (state == S_IDLE) begin
            if (we_i) begin
               cmd <= {8'h02, adr_i[23:0], dat_i[7:0], dat_i[15:8], dat_i[23:16], dat_i[31:24]};
               nbits <= 32 + ((sel_i == 4'b0001) ? BYTE : (sel_i == 4'b0011) ? HALF : WORD);
            end else begin
               cmd <= {8'h03, adr_i[23:0], 32'b0};
               nbits <= 64;
            end
         end else if (state[2] == 1)
            cmd <= { cmd[62:0], spi_data_i };
      end		


	// Counters
	// --------

	always @(posedge clk)
      case (state)
         S_STARTUP: begin
            last_bit <= 0;
            bit_counter <= 0;
         end
			S_IDLE: begin
            last_bit <= 0;
            bit_counter <= 0;
         end
         S_SEND_RSTEN: begin
            bit_counter <= bit_counter + 1;
            last_bit <= (bit_counter == (nbits - 1));
            wait_counter <= 0;
         end
         S_WAIT_RSTEN: begin
            last_bit <= 0;
            bit_counter <= 0;
            wait_counter <= wait_counter + 1;
            last_wait <= (wait_counter == 8'hf);
         end
         S_SEND_RST: begin
            bit_counter <= bit_counter + 1;
            last_bit <= (bit_counter == (nbits - 1));
            wait_counter <= 0;
         end
         S_WAIT_RST: begin
            last_bit <= 0;
            bit_counter <= 0;
            wait_counter <= wait_counter + 1;
            last_wait <= (wait_counter == 8'hf);
         end
			S_SEND_BYTE: begin
				bit_counter <= bit_counter + 1;
            last_bit <= (bit_counter == (nbits - 1));
         end
         default: begin

         end
		endcase

	// User IF
	// -------
	// Data readout
   assign ack_o = (state == S_IDLE) & last_bit;
	assign dat_o = ack_o ? { cmd[7:0], cmd[15:8], cmd[23:16], cmd[31:24] } : 32'd0;

	// IO control
	// ----------

	assign spi_data_o = (state[2] == 1) ? cmd[63] : 0;
	assign spi_cs_o = (state[3] != 1);
	assign spi_clk_o  = (state[2] == 1) ? clk : 0;



endmodule
`endif
