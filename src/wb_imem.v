`ifndef __WB_IMEM__
`define __WB_IMEM__

module wb_imem(
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
               output reg         spi_cs_o,
               output wire        spi_data_o
               );

   /* verilator lint_off UNUSEDSIGNAL */
  wire [31:24] dummy1;
  assign dummy1 = adr_i[31:24];
   wire [31:0] dummy2;
   assign dummy2 = dat_i[31:0];
   wire [3:0] dummy3;
   assign dummy3 = sel_i;
   /* verilator lint_on UNUSEDSIGNAL */

   localparam                     S_IDLE = 2'd0;
   localparam                     S_SENDING = 2'd1;
   localparam                     S_RECEIVING = 2'd2;
   localparam                     S_WRITEBACK = 2'd3;

   reg [1:0]                      state;
   reg [5:0]                      bits_left;
   reg [31:0]                     cmd;

   always @(negedge clk or negedge rst_n) begin
      if (!rst_n) begin
         state <= S_IDLE;
         bits_left <= 0;
         spi_cs_o <= 1;
         cmd <= 0;
      end else begin
         case (state)
           S_IDLE: begin
              if (stb_i & cyc_i & !we_i) begin
                 state <= S_SENDING;
                 bits_left <= 6'd32;
                 spi_cs_o <= 0;
                 cmd <= {8'h03, adr_i[23:0]};
              end
           end
           S_SENDING: begin
              cmd <= {cmd[30:0], 1'b0};
              bits_left <= bits_left - 6'd1;
              if (bits_left == 1) begin
                 state <= S_RECEIVING;
                 bits_left <= 6'd32;
              end
           end
           S_RECEIVING: begin
              bits_left <= bits_left - 6'd1;
              cmd <= {cmd[30:0], spi_data_i};
              if (bits_left == 0) begin
                 state <= S_IDLE;
                 spi_cs_o <= 1'b1;
              end
           end
           S_WRITEBACK: begin
              state <= S_IDLE;
           end
         endcase
      end
   end // always @ (negedge clk)

   assign ack_o = (state == S_RECEIVING) && (bits_left == 0);
   assign dat_o =  ack_o ? {cmd[7:0], cmd[15:8], cmd[23:16], cmd[31:24]} : 32'd0;
   assign spi_clk_o = clk & ~spi_cs_o;
   assign spi_data_o = (state == S_SENDING) ? cmd[31] : 1'b0;

endmodule
`endif
