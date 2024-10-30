`ifndef __WB_COPROC__
`define __WB_COPROC__

`define SLL 5'h08
`define SRL 5'h0C
`define SRA 5'h10
`define AND 5'h14
`define OR 5'h18
`define XOR 5'h1C

module wb_coproc(
               input wire         clk,
               input wire         rst_n,
               input wire [4:0]   adr_i, // ADR_I() address
               input wire [31:0]  dat_i, // DAT_I() data in
               input wire         we_i,  // WE_I write enable input
               input wire         stb_i, // STB_I strobe input
               input wire         cyc_i, // CYC_I cycle input,
               output reg [31:0]  dat_o, // DAT_O() data out
               output reg         ack_o  // ACK_O acknowledge output
               );


   // Memory Map
   // WRITE ONLY
   // 0x00: op a
   // 0x04: op b
   // READ ONLY
   // 0x08: sll
   // 0x0C: slr
   // 0x10: sla
   // 0x14: and
   // 0x18: or
   // 0x1C: xor

   reg [31:0]                     opa;
   reg [31:0]                     opb;

   wire [31:0]                    res_sll = opa << opb[4:0];
   wire [31:0]                    res_srl = opa >> opb[4:0];
   wire [31:0]                    res_sra = $signed(opa) >>> opb[4:0];
   wire [31:0]                    res_and = opa & opb;
   wire [31:0]                    res_or  = opa | opb;
   wire [31:0]                    res_xor = opa ^ opb;

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         opa <= 32'd0;
         opb <= 32'd0;
         ack_o <= 1'b0;
         dat_o <= 32'd0;
      end else begin
         if (cyc_i & stb_i & ~ack_o) begin
            // write operator registers
            if (we_i) begin
               if (adr_i[4:0] == 5'h0) begin
                  opa <= dat_i;
               end else if (adr_i[4:0] == 5'h4) begin
                  opb <= dat_i;
               end
            end else begin
               casez (adr_i[4:0])
                 `SLL: dat_o <= res_sll;
                 `SRL: dat_o <= res_srl;
                 `SRA: dat_o <= res_sra;
                 `AND: dat_o <= res_and;
                 `OR : dat_o <= res_or;
                 `XOR: dat_o <= res_xor;
                 default: dat_o <= 32'd0;
               endcase
            end
            ack_o <= 1'b1;
         end else begin // if (cyc_i & stb_i & ~ack_o)
            ack_o <= 1'b0;
         end
      end
   end

endmodule
`endif
