module wb_gpio(
               input wire         clk,
               input wire         rst,
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

   reg    [3:0]                       data_o;
   reg    [3:0]                       data_i;
   
   assign gpio_o = data_o;
   assign data_i = gpio_i;

   always @(posedge clk) begin
      if (rst) begin
         ack_o <= 1'b0;
      end else begin
         ack_o <= 1'b0;
         dat_o <= 32'd0;
         
         if (cyc_i & stb_i & ~ack_o) begin
            if (we_i) begin
               data_o[adr_i[1:0]] <= dat_i[0];
            end else begin
               dat_o <= {31'b0, data_i[adr_i[1:0]]};
            end
            ack_o <= 1'b1;
         end
      end
   end

endmodule