module decoder (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] decoder_inst,
    input  wire        decoder_renable,
    output wire        decoder_res,
    output wire        decoder_funct7,
    output wire [ 2:0] decoder_funct3,
    output wire [ 8:0] decoder_pc,
    output wire [31:0] decoder_imm,
    output wire [ 4:0] decoder_rs1,
    output wire [ 4:0] decoder_rs2,
    output wire [ 4:0] decoder_rd,
    output wire [ 3:0] decoder_strb,
    output wire        decoder_sign_extend,
    output wire        decoder_load,
    output wire        decoder_store,
    output wire        decoder_rtype
);


   reg [31:0]                     instruction = 0;
   reg [15:0]                     rom [0:127];
   reg [15:0]                     decoded = 16'b0;

   localparam opcode_R =      5'b01100; // opshort = 3'b110                
   localparam opcode_I =      5'b00100; // opshort = 3'b010                
   localparam opcode_I_load = 5'b00000; // opshort = 3'b000                
   localparam opcode_S =      5'b01000; // opshort = 3'b100    func7 = 0        
   localparam opcode_B =      5'b11000; // opshort = 3'b100    func7 = 1    
   localparam opcode_J =      5'b11011; // opshort = 3'b101    func7 = 0
   localparam opcode_JALR =   5'b11001; // opshort = 3'b101    func7 = 1
   localparam opcode_LUI =    5'b01101; // opshort = 3'b111          
   localparam opcode_AUIPC =  5'b00101; // opshort = 3'b011          


   // opshort = 3'b001 is illegal, but does not happen with valid RISCV-32I Instructions
   // normally S, B, J and JALR have no defined func7 value
   // we "artificially" create one here, since we use func7 as the highest bit
   // to uniquely identify all RISCV32I operations with a small number of bits
   // opshort is generated by extracting {opcode[3:2], opcode[0]}


   wire [4:0] opcode = decoder_inst[6:2];
   
   wire [2:0] funct3 = (opcode == opcode_J || opcode == opcode_LUI || opcode == opcode_AUIPC) ? 3'b000 : decoder_inst[14:12];
   wire funct7 = ((opcode == opcode_R) || (opcode == opcode_I && (decoder_inst[14:12] == 3'b001 || decoder_inst[14:12] == 3'b101))) ? decoder_inst[30] : (opcode == opcode_B || opcode == opcode_JALR) ? 1'b1 : 1'b0;
   wire [2:0] opshort = {opcode[3:2], opcode[0]};

   // extract opcode, 7 bits, but can be expressed by 4, possibly 3 if func7 bit is hijacked
   // extract func3, 3 bits
   // extract func7, 7 bits, but only 1 bit ever changes

   //wire                           funct7 = ((decoder_inst[6:2] == 5'b00100) && (decoder_inst[14:12] == 3'b101)) || 
   //                               ((decoder_inst[6:2] == 5'b01100) && ((decoder_inst[14:12] == 3'b000) || (decoder_inst[14:12] == 3'b101))) ? decoder_inst[30] : 0;
   wire [6:0]                     code = {funct7, funct3, opshort};
   wire [2:0]                     itype = decoded[15:13];
   //wire [4:0]                     opcode = instruction[6:2];
   
   always @(posedge clk) begin
      if (decoder_renable && !reset) begin
	 instruction <= decoder_inst;
         decoded <= rom[code];
      end
   end

   //wire is_jalr = instruction[6:2] == 5'b11001;
   assign decoder_pc = {1'b0, decoded[7:0]};
   // assign decoder_funct7 = ((opcode == 7'b0010011) && (funct3 == 3'b101)) || 
   //                         ((opcode == 7'b0110011) && ((funct3 == 3'b000) || (funct3 == 3'b101))) ? instruction[30] : 0;
   assign decoder_funct7 = ((opcode == opcode_R) || (opcode == opcode_I && (decoder_inst[14:12] == 3'b001 || decoder_inst[14:12] == 3'b101))) ? instruction[30] : 1'b0;
   assign decoder_funct3 = instruction[14:12];
   assign decoder_rs2 = (itype == 3'd5 ? 5'b0 : instruction[24:20]);
   assign decoder_rs1 = decoder_renable ? decoder_inst[19:15] : instruction[19:15];
   assign decoder_rd = ((itype == 3'd1 | itype == 3'd2) ? 5'b0 : instruction[11:7]);
   assign decoder_res = decoded[12];
   assign decoder_load = decoded[11];
   assign decoder_store = decoded[10];
   assign decoder_rtype = itype == 3'd6;
   assign decoder_imm = itype == 3'd0 ? {{21{instruction[31]}}, instruction[30:20]} : // I
			itype == 3'd1 ? {{21{instruction[31]}} , instruction[30:25], instruction[11:7]} : // S
			itype == 3'd2 ? {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0} : // B
			itype == 3'd3 ? {instruction[31:12], 12'b0} : // U
			itype == 3'd4 ? {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0} : // J
                        itype == 3'd5 ? {27'b0, {instruction[24:20]}} : // Si
                        itype == 3'd6 ?  0 : 0; // R/S
   assign decoder_strb = decoder_funct3 == 3'b000 ? 4'b0001 :     // B
			 decoder_funct3 == 3'b001 ? 4'b0011 :     // H
			 decoder_funct3 == 3'b010 ? 4'b1111 : 0 ; // W
   assign decoder_sign_extend = itype[2];

   integer i;
   initial begin
      for (i=0; i < 256; i=i+1) begin
         rom[i] = 16'b0;
      end

      //itype_res_load store_reserved_addr
      //[15:13]_[12]_[11][10]_[9:8]_[7:0]
      rom[108] = 16'b010_0_00_00_01011110; //   BGE
      rom[ 38] = 16'b110_1_00_00_01100011; //   XOR
      rom[ 68] = 16'b010_0_00_00_00110101; //   BEQ
      rom[  7] = 16'b011_1_00_00_00000000; //   LUI
      rom[110] = 16'b110_1_00_00_10110010; //   SRA
      rom[ 69] = 16'b000_1_00_00_00011010; //  JALR
      rom[ 18] = 16'b000_1_00_00_11011010; //  SLTI
      rom[  5] = 16'b100_1_00_00_00010010; //   JAL
      rom[ 32] = 16'b000_1_10_00_00001110; //   LBU
      rom[ 40] = 16'b000_1_10_00_00001110; //   LHU
      rom[  2] = 16'b000_1_00_00_00000000; //  ADDI
      rom[ 70] = 16'b110_1_00_00_00000100; //   SUB
      rom[ 14] = 16'b110_1_00_00_10100111; //   SLL
      rom[ 54] = 16'b110_1_00_00_01111011; //    OR
      rom[ 22] = 16'b110_1_00_00_11011010; //   SLT
      rom[106] = 16'b101_1_00_00_10110010; //  SRAI
      rom[ 20] = 16'b001_0_01_00_00001110; //    SW
      rom[ 12] = 16'b001_0_01_00_00001110; //    SH
      rom[ 16] = 16'b000_1_10_00_00001110; //    LW
      rom[100] = 16'b010_0_00_00_01010010; //   BLT
      rom[ 26] = 16'b000_1_00_00_11010001; // SLTIU
      rom[ 58] = 16'b000_1_00_00_10010010; //  ANDI
      rom[ 42] = 16'b101_1_00_00_10110111; //  SRLI
      rom[  8] = 16'b000_1_10_00_00001110; //    LH
      rom[  0] = 16'b000_1_10_00_00001110; //    LB
      rom[ 76] = 16'b010_0_00_00_01000000; //   BNE
      rom[  6] = 16'b110_1_00_00_00000000; //   ADD
      rom[ 46] = 16'b110_1_00_00_10110111; //   SRL
      rom[ 50] = 16'b000_1_00_00_01111011; //   ORI
      rom[ 62] = 16'b110_1_00_00_10010010; //   AND
      rom[  4] = 16'b001_0_01_00_00001110; //    SB
      rom[124] = 16'b010_0_00_00_01010111; //  BGEU
      rom[ 10] = 16'b101_1_00_00_10100111; //  SLLI
      rom[116] = 16'b010_0_00_00_01001011; //  BLTU
      rom[ 30] = 16'b110_1_00_00_11010001; //  SLTU
      rom[  3] = 16'b011_1_00_00_00000110; // AUIPC
      rom[ 34] = 16'b000_1_00_00_01100011; //  XORI
   end
endmodule

