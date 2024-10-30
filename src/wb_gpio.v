`ifndef __WB_GPIO__
`define __WB_GPIO__

module wb_gpio(
               input wire         clk,
               input wire         rst_n,
               input wire [31:0]  adr_i, // ADR_I() address
               input wire [31:0]  dat_i, // DAT_I() data in
               output reg [31:0] dat_o, // DAT_O() data out
               input wire         we_i, // WE_I write enable input
               input wire [3:0]   sel_i, // SEL_I() select input
               input wire         stb_i, // STB_I strobe input
               output reg         ack_o, // ACK_O acknowledge output
               input wire         cyc_i, // CYC_I cycle input,
               input wire  [3:0]  gpio_i,
               output wire [3:0]  gpio_o
               );

   /* verilator lint_off UNUSEDSIGNAL */
  wire [31:2] dummy1;
  assign dummy1 = adr_i[31:2];
  wire [31:1] dummy2;
  assign dummy2 = dat_i[31:1];
   wire [3:0] dummy3;
   assign dummy3 = sel_i;
   /* verilator lint_on UNUSEDSIGNAL */

   reg    [3:0]                       data_o;
   wire   [3:0]                       data_i;
   
   assign gpio_o = data_o;
   assign data_i = gpio_i;

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         ack_o <= 1'b0;
         data_o <= 4'b1010; // just to see if anything works, standard output 1010 on reset
         dat_o <= 32'd0;
      end else begin     
         if (cyc_i & stb_i & ~ack_o) begin
            if (we_i) begin
               data_o[adr_i[1:0]] <= dat_i[0];
            end else begin
               dat_o <= {31'b0, data_i[adr_i[1:0]]};
            end
            ack_o <= 1'b1;
         end else
            ack_o <= 1'b0;
      end
   end

endmodule
`endif
