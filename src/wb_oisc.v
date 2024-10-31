/*
 * Copyright (c) 2022 Lucas Klemmer
 * Copyright (c) 2022 Felix Roithmayr
 * SPDX-License-Identifier: Apache-2.0
 */

`ifndef __WB_OISC__
`define __WB_OISC__
`include "decoder.v"

`define TMP0 6'd0
`define RVPC 6'd1
`define SRC1 6'd2
`define TMP1 6'd3
`define SRC2 6'd4
`define TMP2 6'd5
`define TMP3 6'd6
`define TMP4 6'd7
`define IMMI 6'd8
`define TMP5 6'd9
`define ONE 6'd10
`define WORD 6'd11
`define INCR 6'd12
`define NEXT 6'd13
`define TMP6 6'd14

`define RV_REGS(DEST) {1'b1, DEST}
`define MICRO_REGS(DEST) {2'b00, DEST}

module wb_oisc (
                input wire         clk,
                input wire         rst_n,

                input wire         wb_ack_i,
                input wire [31:0]  wb_dat_i,
                output wire        wb_cyc_o,
                output wire        wb_stb_o,
                output wire [3:0]  wb_sel_o,
                output wire        wb_we_o,
                output reg [31:0]  wb_dat_o,
                output wire [31:0] wb_adr_o);

   /* verilator lint_off UNUSEDSIGNAL */
   wire dummy1;
   assign dummy1 = decoder_sign_extend;
   wire dummy2;
   assign dummy2 = decoder_funct7;
   wire dummy3;
   assign dummy3 = res[32];
   /* verilator lint_on UNUSEDSIGNAL */

   // RISC-V IF state definitions
   localparam FETCH_RVPC_BIT      = 0;
   localparam FETCH_INSTR_BIT     = 1;
   localparam PLACE_SRC1_BIT      = 2;
   localparam PLACE_SRC2_BIT      = 3;
   localparam PLACE_IMM_BIT       = 4;
   localparam EXECUTE_BIT         = 5;
   localparam MEMORY_BIT          = 6;
   localparam NB_STATES           = 7;

   localparam MICRO_FETCH_BIT     = 0;
   localparam MICRO_EXECUTE_BIT   = 1;
   localparam MICRO_WRITEBACK_BIT = 2;
   localparam MICRO_NB_STATES     = 3;

   localparam FETCH_RVPC          = 1 << FETCH_RVPC_BIT;
   //localparam FETCH_INSTR         = 1 << FETCH_INSTR_BIT;
   //localparam PLACE_SRC1          = 1 << PLACE_SRC1_BIT;
   //localparam PLACE_SRC2          = 1 << PLACE_SRC2_BIT;
   //localparam PLACE_IMM           = 1 << PLACE_IMM_BIT;
   //localparam EXECUTE             = 1 << EXECUTE_BIT;
   localparam MEMORY              = 1 << MEMORY_BIT;

   // SUBLEQ core FSM states
   localparam MICRO_FETCH         = 1 << MICRO_FETCH_BIT;
   //localparam MICRO_EXECUTE       = 1 << MICRO_EXECUTE_BIT;
   //localparam MICRO_WRITEBACK     = 1 << MICRO_WRITEBACK_BIT;

   // ------------------------------------------------------------
   /** microcode ROM */
   /* verilator lint_off LITENDIAN */
   localparam [0:(256*16)-1] rom = {
      16'h30FF,16'hD101,16'h0001,16'hA301,16'h2802,16'h3301,16'h0004,16'h2003,16'h0001,16'h0005,16'h2007,16'h0001,16'h8004,16'h3301,16'h0001,16'h04FF,
      16'h0001,16'hD101,16'h00F0,16'hC901,16'h0201,16'h2001,16'h0001,16'h9006,16'h0001,16'h0401,16'h4001,16'h0001,16'h0004,16'hC401,16'h0401,16'h4001,
      16'h0001,16'h2006,16'h0001,16'h0901,16'h8001,16'hB901,16'h9901,16'h4401,16'h0001,16'h0003,16'hA401,16'h2003,16'h4401,16'h0001,16'h32FF,16'hD101,
      16'hC0FD,16'h2301,16'h3301,16'h3201,16'h8004,16'h2201,16'h2301,16'h3301,16'h0001,16'h03FF,16'h0001,16'hD101,16'hC5F2,16'h0801,16'h8001,16'h0001,
      16'h0201,16'h2001,16'h0001,16'hC301,16'h8002,16'h0001,16'h2004,16'h0001,16'h0301,16'h3001,16'h0001,16'h3304,16'hB501,16'h5501,16'h03FF,16'h0001,
      16'hD101,16'hC5F0,16'h0801,16'h8001,16'h0001,16'h0201,16'h2001,16'h0001,16'hC301,16'h8002,16'h0001,16'h0005,16'hC301,16'h2003,16'h0001,16'h0301,
      16'h3001,16'h0001,16'h3304,16'hB501,16'h5501,16'h03FF,16'h0001,16'hD101,16'hC5EF,16'h0801,16'h8001,16'h0001,16'h0201,16'h2001,16'h0001,16'hC301,
      16'h8002,16'h0001,16'h0005,16'h8004,16'h0001,16'h2004,16'h0001,16'h0301,16'h3001,16'h0001,16'h3304,16'hB501,16'h5501,16'h01FF,16'h8001,16'h0001,
      16'hD1FF,16'h2402,16'h3303,16'h2302,16'h3303,16'h2305,16'h4003,16'h3301,16'h0001,16'hD1FF,16'h01FF,16'h8001,16'h0001,16'h2404,16'h3305,16'h2302,
      16'h3303,16'h2305,16'h4003,16'h3301,16'h0001,16'hD1FF,16'h51FF,16'h8501,16'h5501,16'h3404,16'h0002,16'h4202,16'h0301,16'h2001,16'h3301,16'h0001,
      16'h01FF,16'h8001,16'h0001,16'hD1FF,16'h3402,16'h0002,16'h4202,16'h0301,16'h2001,16'h3301,16'h0001,16'h02FF,16'h2201,16'h3101,16'h1101,16'h1001,
      16'h0001,16'hD101,16'h8301,16'h6801,16'h8801,16'hC601,16'h8002,16'h0001,16'hC0FD,16'h5801,16'h8501,16'h5501,16'h8601,16'hC001,16'hB001,16'h3301,
      16'h3801,16'h2301,16'h6601,16'h5501,16'h3301,16'h0001,16'hD4FF,16'h3401,16'h0101,16'h1301,16'h8001,16'h4401,16'h3301,16'h0001,16'h02FF,16'hD101,
      16'h8001,16'h0001,16'h04FF,16'hD101,16'h8001,16'h0001,16'h0401,16'h1001,16'h4401,16'h0001,16'h82FF,16'hD101,16'h02FF,16'hD101,16'h8001,16'h0001,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000
      };
   /* verilator lint_on LITENDIAN */


   // ------------------------------------------------------------
   /** register bank */
   reg [31:0]                                              regs [63:0];

   wire [5:0] 		      reg_wa = 
			      state[PLACE_SRC1_BIT] ? `SRC1 :
               state[PLACE_SRC2_BIT] ? (decoder_rtype ? `IMMI : `SRC2) :
			      state[PLACE_IMM_BIT]  ? (decoder_rtype ? `SRC2 : `IMMI) :
                              state[EXECUTE_BIT] & micro_done & decoder_res           ? `RV_REGS(decoder_rd) :
                              state[MEMORY_BIT] & decoder_load                        ? `RV_REGS(decoder_rd) :
			      (state[EXECUTE_BIT] & micro_state[MICRO_WRITEBACK_BIT]) ? `MICRO_REGS(micro_res_addr) : 6'd32;
   wire [5:0]                 reg_ra = 
                              state[FETCH_RVPC_BIT]                                   ? `RVPC :
                              state[FETCH_INSTR_BIT] & wb_ack_i                       ? `RV_REGS(decoder_rs1) :
			      state[PLACE_SRC1_BIT]                                   ? `RV_REGS(decoder_rs2) : 
			      state[EXECUTE_BIT] & micro_state[MICRO_EXECUTE_BIT]     ? `MICRO_REGS(micro_op[15:12]) : 6'd32;
   wire [5:0]                 reg_rb =
                              (state[EXECUTE_BIT] & micro_state[MICRO_EXECUTE_BIT])   ? `MICRO_REGS(micro_op[11:8]) :
                              micro_done                                              ? 6'b000100 : 6'd32;
   wire [31:0]                reg_wdata = 
                              (state[PLACE_SRC1_BIT] | state[PLACE_SRC2_BIT]) ? op_a : 
			      (state[PLACE_IMM_BIT])                          ? decoder_imm : 
			      (state[MEMORY_BIT] & decoder_load)              ? mem_load_data : res[31:0];
   wire                       reg_we = (state[PLACE_SRC1_BIT]
					| state[PLACE_SRC2_BIT]
					| state[PLACE_IMM_BIT]
					| (state[FETCH_RVPC_BIT])
					| (state[EXECUTE_BIT] & micro_state[MICRO_WRITEBACK_BIT])
					| (state[MEMORY_BIT] & decoder_res)) & (reg_wa != 6'd32);

   // ------------------------------------------------------------
   
   reg [7:0] 		      micro_pc = 8'b0;
   reg [15:0]                 micro_op = 16'b0;
   reg [31:0]                 op_a = 32'b0;
   reg [31:0]                 op_b = 32'b0;
   wire [7:0]                 op_jump = micro_op[7:0];
   wire [7:0]                 op_jump_neg = ~micro_op[7:0] + 1;
   wire                       micro_done = micro_state[MICRO_WRITEBACK_BIT] & (op_jump == 8'b11111111);
   wire [32:0]                res = $signed(op_b) - $signed(op_a);

   // ------------ Memory Alignment ------------
   // following by https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/RTL/PROCESSOR/femtorv32_quark.v
   reg [1:0]                  mem_addr_lowbits = 0;
   always @(posedge clk) mem_addr_lowbits <= wb_adr_o[1:0];
   
   wire                       mem_byte_access = decoder_funct3[1:0] == 2'b00;
   wire                       mem_half_access = decoder_funct3[1:0] == 2'b01;
   wire                       mem_load_sign = !decoder_funct3[2] & (mem_byte_access ? mem_load_byte[7] : mem_load_half[15]);
   wire [31:0]                mem_load_data = 
                              mem_byte_access ? {{24{mem_load_sign}}, mem_load_byte} :
			      mem_half_access ? {{16{mem_load_sign}}, mem_load_half} :
                              wb_dat_i;
   wire [15:0]                mem_load_half = mem_addr_lowbits[1] ? wb_dat_i[31:16] : wb_dat_i[15:0];
   wire [7:0]                 mem_load_byte = mem_addr_lowbits[0] ? mem_load_half[15:8] : mem_load_half[7:0];

   // ----------------------------------------
   
   wire [31:0] wire_a = (reg_ra > 6'd15) && (reg_ra < 6'd33) ? 32'd0 : regs[reg_ra];
   wire [31:0] wire_b = (reg_rb > 6'd15) && (reg_rb < 6'd33) ? 32'd0 : regs[reg_rb];

   reg [3:0]                  micro_res_addr;
   
   always @ (posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         micro_res_addr <= 0;
      end else begin
         if (state[PLACE_SRC2_BIT]) begin
            micro_pc <= decoder_micro_pc;
         end else if (state[EXECUTE_BIT] & micro_state[MICRO_WRITEBACK_BIT] & ~micro_done) begin
            if ($signed(op_b) <= $signed(op_a)) begin
                     if (op_jump[7]) begin
                        micro_pc <= micro_pc - op_jump_neg;
                     end else begin
                        micro_pc <= micro_pc + op_jump;
                     end
            end else begin
               micro_pc <= micro_pc + 1;
            end
         end else if (micro_done) begin
            micro_pc <= 0;
         end else begin
            micro_pc <= micro_pc;
         end

         micro_res_addr <= reg_rb[3:0];
      end
   end

   // process for reading from the microcode ROM
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         micro_op <= 0;
      end else begin
         if (state[EXECUTE_BIT] & micro_state[MICRO_FETCH_BIT] | micro_done) begin
            micro_op <= rom[micro_pc*16+:16];
         end
      end
   end
   
   // process for reading from regbank
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         op_a <= 0;
         op_b <= 0;
      end else begin
         if (!(state[FETCH_INSTR_BIT] && !wb_ack_i)) begin
            op_a <= wire_a;
            op_b <= wire_b;
         end
      end
      
   end

   // process for writing to the regbank
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         // SUBLEQ REGS
         regs[0] <= 32'd0;          // TMP0
         regs[1] <= 32'h40000000;   // RISC-V pc
         regs[2] <= 32'd0;          // SRC1
         regs[3] <= 32'd0;          // TMP1
         regs[4] <= 32'd0;          // SRC2
         regs[5] <= 32'd0;          // TMP2
         regs[6] <= 32'd0;          // TMP3
         regs[7] <= 32'd0;          // TMP4
         regs[8] <= 32'd0;          // IMM
         regs[9] <= 32'd0;          // TMP5
         regs[10] <= 32'd1;         // ONE value   (1)
         regs[11] <= 32'd31;        // WORD value  (31)
         regs[12] <= -32'd1;        // INC value   (-1)
         regs[13] <= -32'd4;        // NEXT value (-4)
         regs[14] <= 32'd0;         // TMP6
         regs[15] <= 32'd0;         // TMP7

         // RISC-V REGS
         regs[33] <= 32'd0;         // X1
         regs[34] <= 32'h80008000;  // RISC-V sp
         regs[35] <= 32'h80000800;  // RISC-V gp
         regs[36] <= 32'd0;         // X4
         regs[37] <= 32'd0;         // X5
         regs[38] <= 32'd0;         // X6
         regs[39] <= 32'd0;         // X7
         regs[40] <= 32'd0;         // X8
         regs[41] <= 32'd0;         // X9
         regs[42] <= 32'd0;         // X10
         regs[43] <= 32'd0;         // X11
         regs[44] <= 32'd0;         // X12
         regs[45] <= 32'd0;         // X13
         regs[46] <= 32'd0;         // X14
         regs[47] <= 32'd0;         // X15
         regs[48] <= 32'd0;         // X16
         regs[49] <= 32'd0;         // X17
         regs[50] <= 32'd0;         // X18
         regs[51] <= 32'd0;         // X19
         regs[52] <= 32'd0;         // X20
         regs[53] <= 32'd0;         // X21
         regs[54] <= 32'd0;         // X22
         regs[55] <= 32'd0;         // X23
         regs[56] <= 32'd0;         // X24
         regs[57] <= 32'd0;         // X25
         regs[58] <= 32'd0;         // X26
         regs[59] <= 32'd0;         // X27
         regs[60] <= 32'd0;         // X28
         regs[61] <= 32'd0;         // X29
         regs[62] <= 32'd0;         // X30
         regs[63] <= 32'd0;         // X31
      end else begin
         if (reg_we) begin
            regs[reg_wa] <= reg_wdata;	    
         end
      end
   end

   // ------------------------------------------------------------
   // RISC-V Interface

   //(* ehot *)
   reg [NB_STATES-1:0] state = FETCH_RVPC;
   reg [MICRO_NB_STATES-1:0] micro_state = MICRO_FETCH;

   // Wishbone bus signals
   wire                      wb_write_transaction = state[EXECUTE_BIT] & micro_done & decoder_store;
   wire                      wb_read_transaction = state[EXECUTE_BIT] & micro_done & decoder_load;
   
   assign wb_stb_o = wb_write_transaction | wb_read_transaction | state[FETCH_INSTR_BIT];// | state[MEMORY_BIT];
   assign wb_cyc_o = wb_stb_o;
   assign wb_sel_o = wb_stb_o ? decoder_strb : -1;
   assign wb_adr_o = state[FETCH_INSTR_BIT] ? op_a :
                     wb_write_transaction | wb_read_transaction ? res[31:0] : 0;
   assign wb_we_o = state[EXECUTE_BIT] & micro_done & decoder_store;
   
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
	      wb_dat_o <= 0;
      end else if (state[PLACE_SRC2_BIT] & decoder_store) begin
	      wb_dat_o <= reg_wdata;
      end
   end

   // RISC-V IF decoder
   wire [7:0] 	       decoder_micro_pc;
   wire [2:0]          decoder_funct3;
   wire                decoder_funct7;
   wire                decoder_res;		// From decoder of decoder.v
   wire [4:0]          decoder_rd;		// From decoder of decoder.v
   wire [4:0]          decoder_rs1;		// From decoder of decoder.v
   wire [4:0]          decoder_rs2;		// From decoder of decoder.v
   wire [31:0]         decoder_imm;
   wire [3:0]          decoder_strb;
   wire                decoder_sign_extend;
   wire                decoder_load;
   wire                decoder_store;
   wire                decoder_rtype;

   decoder decoder(
		   // Outputs
		   .decoder_res		(decoder_res),
		   .decoder_funct3      (decoder_funct3),
		   .decoder_funct7	(decoder_funct7),
		   .decoder_pc		(decoder_micro_pc),
		   .decoder_imm		(decoder_imm),
		   .decoder_rs1		(decoder_rs1),
		   .decoder_rs2		(decoder_rs2),
		   .decoder_rd		(decoder_rd),
		   .decoder_load        (decoder_load),
		   .decoder_store       (decoder_store),
		   .decoder_strb        (decoder_strb),
		   .decoder_sign_extend (decoder_sign_extend),
		   // Inputs
		   .clk			(clk),
		   .rst_n		(rst_n),
		   .decoder_inst	(wb_dat_i),
		   .decoder_renable	((state[FETCH_INSTR_BIT] && wb_ack_i)),
                   .decoder_rtype (decoder_rtype));

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         state <= FETCH_RVPC;
         micro_state <= MICRO_FETCH;
      end else begin
         if (state[EXECUTE_BIT]) begin
            if (micro_done) begin
               if (decoder_load | (decoder_store & ~wb_ack_i)) begin
                  state <= MEMORY;
               end else begin
                  state <= FETCH_RVPC;
               end
               micro_state <= MICRO_FETCH;
            end else begin
               micro_state <= {micro_state[MICRO_NB_STATES-2:0], micro_state[MICRO_NB_STATES-1]};
            end
         end else begin
            if (//!(state[DECODE_INSTR_BIT] & !wb_ack_i) &&
                !(state[FETCH_INSTR_BIT] & !wb_ack_i) &&
                !(state[MEMORY_BIT] & !wb_ack_i)) begin
               state <= {state[NB_STATES-2:0], state[NB_STATES-1]};
            end
         end
      end
   end // always @ (posedge clk)
   
endmodule
`endif
