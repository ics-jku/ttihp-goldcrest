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
`define MICRO_REGS(DEST) {2'b0, DEST}

module wb_oisc #(parameter CLK_DIV = 2)(
	                                input wire         clk,
	                                input wire         reset,

                                        input wire         wb_ack_i,
                                        input wire [31:0]  wb_dat_i,
	                                output wire        wb_cyc_o,
                                        output wire        wb_stb_o,
                                        output wire [3:0]  wb_sel_o,
                                        output wire        wb_we_o,
                                        output reg [31:0]  wb_dat_o,
                                        output wire [31:0] wb_adr_o);

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
   localparam FETCH_INSTR         = 1 << FETCH_INSTR_BIT;
   localparam PLACE_SRC1          = 1 << PLACE_SRC1_BIT;
   localparam PLACE_SRC2          = 1 << PLACE_SRC2_BIT;
   localparam PLACE_IMM           = 1 << PLACE_IMM_BIT;
   localparam EXECUTE             = 1 << EXECUTE_BIT;
   localparam MEMORY              = 1 << MEMORY_BIT;

   // SUBLEQ core FSM states
   localparam MICRO_FETCH         = 1 << MICRO_FETCH_BIT;
   localparam MICRO_EXECUTE       = 1 << MICRO_EXECUTE_BIT;
   localparam MICRO_WRITEBACK     = 1 << MICRO_WRITEBACK_BIT;

   // ------------------------------------------------------------
   /** microcode ROM */
   reg [15:0]                                              rom [0:255];

   initial $readmemh("microcode/microcode.hex", rom);

   // ------------------------------------------------------------
   /** register bank */
   reg [31:0]                                              regs [63:0];

   // we need this to force the regbank into the vcd
   //integer                                                 idx;
   //initial begin
   //   #0 for(idx = 0; idx < 16; idx = idx+1) $dumpvars(0, regs[idx]);
   //   #0 for(idx = 32; idx < 64; idx = idx+1) $dumpvars(0, regs[idx]);
   //end

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

   // Initialize regbank
   integer                    i;
   initial begin
      for (i=0; i < 64; i=i+1) begin
         regs[i] = 0;
      end
      // SUBLEQ REGS
      regs[1]  = 32'h40000000; // RISC-V pc
      regs[34] = 32'h80008000; // RISC-V sp
      regs[35] = 32'h80000800; // RISC-V gp


      regs[8] = -32'd4; // preload immidiate reg
      regs[10] = 32'd1; // ONE value   (1)
      regs[11] = 32'd31; // WORD value  (31)
      regs[12] = -32'd1; // INC value   (-1)
      regs[13] = -32'd4; // NEXT value (-4)
   end

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
   
   reg [3:0]                  micro_res_addr;
   
   always @ (posedge clk) begin
      micro_res_addr <= 0;
      
      if (!reset) begin
	 if (state[PLACE_SRC2_BIT]) begin
	    micro_pc <= decoder_micro_pc[7:0];
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
   end // always @ (posedge clk)

   // process for reading from the microcode ROM
   always @(posedge clk) begin
      
      if (!reset) begin
         if (state[EXECUTE_BIT] & micro_state[MICRO_FETCH_BIT] | micro_done) begin
            micro_op <= rom[micro_pc];
         end
      end else begin
         micro_op <= 0;
         for (i=0; i < 64; i=i+1) begin
            regs[i] <= 0;
         end
         // SUBLEQ REGS
         regs[1]  <= 32'h40000000; // RISC-V pc
         regs[34] <= 32'h80008000; // RISC-V sp
         regs[35] <= 32'h80000800; // RISC-V gp


         regs[8] <= -32'd4; // preload immidiate reg
         regs[10] <= 32'd1; // ONE value   (1)
         regs[11] <= 32'd31; // WORD value  (31)
         regs[12] <= -32'd1; // INC value   (-1)
         regs[13] <= -32'd4; // NEXT value (-4)
      end
   end
   
   // process for reading from regbank
   always @(posedge clk) begin
      if (!reset && !(state[FETCH_INSTR_BIT] && !wb_ack_i)) begin
	 op_a <= regs[reg_ra];
	 op_b <= regs[reg_rb];
      end
   end

   // process for writing to the regbank
   always @(posedge clk) begin
      if (!reset) begin
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
   
   always @(posedge clk) begin
      if (reset) begin
	 wb_dat_o <= 0;
      end else if (state[PLACE_SRC2_BIT] & decoder_store) begin
	 wb_dat_o <= reg_wdata;
      end
   end

   // RISC-V IF decoder
   wire [8:0] 	       decoder_micro_pc;
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
		   .reset		(reset),
		   .decoder_inst	(wb_dat_i),
		   .decoder_renable	((state[FETCH_INSTR_BIT] && wb_ack_i)),
                   .decoder_rtype (decoder_rtype));

   always @(posedge clk) begin
      state <= state;
      if (!reset) begin
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

   // DEBUG LOGIC
   `ifdef SIMULATION
   reg [8*16-1:0] state_str = "abc";
   reg [31:0] PC;
   reg [31:0] X0;
   reg [31:0] X1;
   reg [31:0] X2;
   reg [31:0] X3;
   reg [31:0] X4;
   reg [31:0] X5;
   reg [31:0] X6;
   reg [31:0] X7;
   reg [31:0] X8;
   reg [31:0] X9;
   reg [31:0] X10;
   reg [31:0] X11;
   reg [31:0] X12;
   reg [31:0] X13;
   reg [31:0] X14;
   reg [31:0] X15;
   reg [31:0] X16;
   reg [31:0] X17;
   reg [31:0] X18;
   reg [31:0] X19;
   reg [31:0] X20;
   reg [31:0] X21;
   reg [31:0] X22;
   reg [31:0] X23;
   reg [31:0] X24;
   reg [31:0] X25;
   reg [31:0] X26;
   reg [31:0] X27;
   reg [31:0] X28;
   reg [31:0] X29;
   reg [31:0] X30;
   reg [31:0] X31;

   assign PC = regs[1];
   assign X0 = regs[32];
   assign X1 = regs[33];
   assign X2 = regs[34];
   assign X3 = regs[35];
   assign X4 = regs[36];
   assign X5 = regs[37];
   assign X6 = regs[38];
   assign X7 = regs[39];
   assign X8 = regs[40];
   assign X9 = regs[41];
   assign X10 = regs[42];
   assign X11 = regs[43];
   assign X12 = regs[44];
   assign X13 = regs[45];
   assign X14 = regs[46];
   assign X15 = regs[47];
   assign X16 = regs[48];
   assign X17 = regs[49];
   assign X18 = regs[50];
   assign X19 = regs[51];
   assign X20 = regs[52];
   assign X21 = regs[53];
   assign X22 = regs[54];
   assign X23 = regs[55];
   assign X24 = regs[56];
   assign X25 = regs[57];
   assign X26 = regs[58];
   assign X27 = regs[59];
   assign X28 = regs[60];
   assign X29 = regs[61];
   assign X30 = regs[62];
   assign X31 = regs[63];

   always @(*) begin
      if (state[FETCH_RVPC_BIT]) state_str = "FETCH_RVPC";
      else if (state[FETCH_INSTR_BIT]) state_str = "FETCH_INSTR";
      //else if (state[DECODE_INSTR_BIT]) state_str = "DECODE_INSTR";
      else if (state[PLACE_SRC2_BIT]) state_str = "PLACE_SRC2";
      else if (state[PLACE_SRC1_BIT]) state_str = "PLACE_SRC1";
      else if (state[PLACE_IMM_BIT]) state_str = "PLACE_IMM";
      else if (state[EXECUTE_BIT]) state_str = "EXECUTE";
      else if (state[MEMORY_BIT]) state_str = "MEMORY";
      //else if (state[WRITE_BACK_BIT]) state_str = "WRITE_BACK";
      else state_str = "???";
   end // always @ (*)

   reg [8*16-1:0] micro_state_str = "abc";
   always @(*) begin
      if (micro_state[MICRO_FETCH_BIT]) micro_state_str = "FETCH";
      else if (micro_state[MICRO_EXECUTE_BIT]) micro_state_str = "EXECUTE";
      else if (micro_state[MICRO_WRITEBACK_BIT]) micro_state_str = "WRITEBACK";
      else micro_state_str = "???";
   end // always @ (*)
   `endif
   
endmodule
