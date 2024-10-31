/*
 * Copyright (c) 2022 Daniel Pekarek
 * Copyright (c) 2022 Lucas Klemmer
 * Copyright (c) 2022 Felix Roithmayr
 * SPDX-License-Identifier: Apache-2.0
 */

`ifndef __UART_RX__
`define __UART_RX__

//////////////////////////////////////////////////////////////////////////////////
// Basic UART receiver with configurable baud rate and word size
//////////////////////////////////////////////////////////////////////////////////
module uart_rx #(
    parameter CLK_FREQ  = 20000000,
    parameter BAUD_RATE = 57600,
    parameter BIT = 8
) (
    input                clk,
    input                rst_n,
    output reg [BIT-1:0] rx_data,
    input                rx_data_start,
    output reg           rx_data_ready,
    input                rx_pin
);

  // calculate the clock cycle for the baud rate
  localparam CYCLE = CLK_FREQ / BAUD_RATE;

  // states of the state machine
  localparam S_IDLE = 0; // idle until listen command
  localparam S_WAIT = 1; // wait for start bit
  localparam S_START = 2;  // start bit
  localparam S_RX = 3;  // data bits
  localparam S_STOP = 4;  // stop bit

  reg [    2:0] state = S_IDLE;
  reg [    2:0] next_state;
  reg [   31:0] cycle_cnt;
  reg [    3:0] bit_cnt;

  // FSM: next state latch
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S_IDLE;
    else state <= next_state;
  end

  // FSM: compute next state
  always @(*) begin
    case (state)
      S_IDLE:
      if (rx_data_start) next_state = S_WAIT;
      else next_state = S_IDLE;
      S_WAIT:
      if (~rx_pin) next_state = S_START;
      else next_state = S_WAIT;
      S_START:
      if (cycle_cnt == CYCLE - 1) next_state = S_RX;
      else next_state = S_START;
      S_RX:
      if ((cycle_cnt == (CYCLE - 1)) && (bit_cnt == (BIT - 1))) next_state = S_STOP;
      else next_state = S_RX;
      S_STOP:
      if (cycle_cnt == CYCLE - 1) next_state = S_IDLE;
      else next_state = S_STOP;
      default: next_state = S_IDLE;
    endcase
  end

  // RX Ready output
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) rx_data_ready <= 1'b0;
    else if (state == S_STOP && cycle_cnt >= (CYCLE / 2)) rx_data_ready <= 1'b1;
    else if (state == S_IDLE) rx_data_ready <= 1'b0;
  end

  // compute bit counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) bit_cnt <= 4'h0;
    else if (state == S_RX)
      if (cycle_cnt == CYCLE - 1) bit_cnt <= bit_cnt + 4'h1;
      else bit_cnt <= bit_cnt;
    else bit_cnt <= 4'h0;
  end

  // compute cycle counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cycle_cnt <= 32'h00;
    else if ((state == S_RX && cycle_cnt == CYCLE - 1) || next_state != state) cycle_cnt <= 32'h00;
    else cycle_cnt <= cycle_cnt + 32'h1;
  end

  // RX bit
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) rx_data <= 8'b0;
    else if (state == S_RX && cycle_cnt == (CYCLE / 2))
      rx_data[bit_cnt[2:0]] <= rx_pin;
  end

endmodule
`endif
