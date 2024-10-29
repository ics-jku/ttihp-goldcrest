module wb_uart(
               input wire         clk,
               input wire         rst,
               input wire [15:0]  adr_i, // ADR_I() address
               input wire [31:0]  dat_i, // DAT_I() data in
               input wire         we_i, // WE_I write enable input
               input wire [3:0]   sel_i, // SEL_I() select input
               input wire         stb_i, // STB_I strobe input
               input wire         cyc_i, // CYC_I cycle input,
               output reg         ack_o, // ACK_O acknowledge output
               output wire [31:0] dat_o, // DAT_O() data out
               output wire        tx,
               input wire         rx
               );

   

   wire [7:0] dat_tmp;
   assign dat_o = {24'b0, dat_tmp};

   wire                           tx_start = stb_i & cyc_i & we_i & sel_i[0];
   wire                           rx_start = stb_i & cyc_i & ~we_i & sel_i[0];
   wire                           tx_ready;
   wire                           rx_ready;
   reg                            working;

   localparam                     S_IDLE = 0;
   localparam                     S_WORKING_TX = 1;
   localparam                     S_WORKING_RX = 2;
   
   reg [1:0]                        state = S_IDLE;
   

   // used to calculate the tx ack
   always @(posedge clk) begin
      if (rst) begin
         state <= S_IDLE;
      end else begin
         ack_o <= 0;
         if (state == S_IDLE) begin
            if (tx_start) begin
               state <= S_WORKING_TX;
            end else if (rx_start) begin
               state <=S_WORKING_RX;
            end
         end else if (state == S_WORKING_TX) begin
            if (tx_ready) begin
               state <= S_IDLE;
               ack_o <= 1;
            end
         end else begin
            if (rx_ready) begin
               state <= S_IDLE;
               ack_o <= 1;
            end
         end
      end
   end // always @ (posedge clk)

   uart_tx uart_tx(.clk(clk),
		   .rst(rst),
		   .tx_data(dat_i[7:0]),
		   .tx_data_valid(tx_start),
		   .tx_data_ready(tx_ready),
		   .tx_pin(tx));

   uart_rx uart_rx(.clk(clk),
		   .rst(rst),
		   .rx_data(dat_tmp),
		   .rx_data_start(rx_start),
		   .rx_data_ready(rx_ready),
		   .rx_pin(rx));

endmodule
