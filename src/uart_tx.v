`ifndef __UART_TX__
`define __UART_TX__

//////////////////////////////////////////////////////////////////////////////////
// Basic UART receiver with configurable baud rate and word size
//////////////////////////////////////////////////////////////////////////////////
module uart_tx #(
    parameter CLK_FREQ  = 20000000,
    parameter BAUD_RATE = 57600,
    parameter BIT       = 8
) (
    input                clk,
    input                rst_n,
    input      [BIT-1:0] tx_data,
    input                tx_data_valid,
    output reg           tx_data_ready,
    output               tx_pin
);

  // calculate the clock cycle for the baud rate
  localparam CYCLE = CLK_FREQ / BAUD_RATE;

  // states of the state machine
  localparam S_IDLE = 0;
  localparam S_START = 1;  // start bit
  localparam S_TX = 2;  // data bits
  localparam S_STOP = 3;  // stop bit

  reg [    1:0] state = S_IDLE;
  reg [    1:0] next_state;
  reg [   31:0] cycle_cnt;
  reg [    3:0] bit_cnt;
  reg [BIT-1:0] tx_data_latch;
  reg           tx_reg;

  assign tx_pin = tx_reg;

  // FSM: next state latch
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S_IDLE;
    else state <= next_state;
  end

  // FSM: compute next state
  always @(*) begin
    case (state)
      S_IDLE:
      if (tx_data_valid) next_state = S_START;
      else next_state = S_IDLE;
      S_START:
      if (cycle_cnt == CYCLE - 1) next_state = S_TX;
      else next_state = S_START;
      S_TX:
      if (cycle_cnt == CYCLE - 1 && bit_cnt == (BIT - 1)) next_state = S_STOP;
      else next_state = S_TX;
      S_STOP:
      if (cycle_cnt == CYCLE - 1) next_state = S_IDLE;
      else next_state = S_STOP;
      default: next_state = S_IDLE;
    endcase
  end

  // TX Ready output
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) tx_data_ready <= 1'b0;
    else if (state == S_IDLE)
      if (tx_data_valid) tx_data_ready <= 1'b0;
      else tx_data_ready <= 1'b1;
    else if (state == S_STOP && cycle_cnt == CYCLE - 1) tx_data_ready <= 1'b1;
  end

  // latch TX data
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) tx_data_latch <= 0;
    else if (state == S_IDLE && tx_data_valid) tx_data_latch <= tx_data;
  end

  // compute bit counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) bit_cnt <= 4'h0;
    else if (state == S_TX)
      if (cycle_cnt == CYCLE - 1) bit_cnt <= bit_cnt + 4'h1;
      else bit_cnt <= bit_cnt;
    else bit_cnt <= 4'h0;
  end

  // compute cycle counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cycle_cnt <= 32'h00;
    else if ((state == S_TX && cycle_cnt == CYCLE - 1) || next_state != state) cycle_cnt <= 32'h00;
    else cycle_cnt <= cycle_cnt + 32'h1;
  end

  // TX bit
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) tx_reg <= 1'b1;
    else
      case (state)
        S_IDLE, S_STOP: tx_reg <= 1'b1;
        S_START: tx_reg <= 1'b0;
        S_TX: tx_reg <= tx_data_latch[bit_cnt[2:0]];
        default: tx_reg <= 1'b1;
      endcase
  end

endmodule
`endif
