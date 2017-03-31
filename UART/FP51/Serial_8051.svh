/*
###############################################################################
# Copyright (c) 2017, PulseRain Technology LLC 
#
# This program is distributed under a dual license: an open source license, 
# and a commercial license. 
# 
# The open source license under which this program is distributed is the 
# GNU Public License version 3 (GPLv3).
#
# And for those who want to use this program in ways that are incompatible
# with the GPLv3, PulseRain Technology LLC offers commercial license instead.
# Please contact PulseRain Technology LLC (www.pulserain.com) for more detail.
#
###############################################################################
*/

`ifndef SERIAL_8051_SVH
`define SERIAL_8051_SVH

`include "common.svh"

    parameter unsigned [1 : 0] SERIAL_8051_MODE_8_BIT_SR    = 2'b00;
    parameter unsigned [1 : 0] SERIAL_8051_MODE_8_BIT_UART  = 2'b10;
     
    parameter int              SERIAL_8051_DEFAULT_DATA_LEN = 8; 


extern module Serial_8051 #(parameter STABLE_TIME, MAX_BAUD_PERIOD) (
    
    //=======================================================================
    // clock / reset
    //=======================================================================
        
    input   wire                                clk,
    input   wire                                reset_n,
    
    //=======================================================================
    // host interface
    //=======================================================================
    
    input   wire                                start_TX,
    input   wire                                start_RX,
    
    input   wire                                class_8051_unit_pulse,
    input   wire                                timer_trigger,
    input   wire unsigned [7 : 0]               SBUF_in,
    input   wire unsigned [2 : 0]               SM,
    input   wire                                REN,
    output  logic unsigned [7 : 0]              SBUF_out,
    
    output  logic                               TI, // TX interrupt
    output  logic                               RI, // RX interrupt
    
    //=======================================================================
    // device interface
    //=======================================================================
    
    input   wire                                RXD,
    output  wire                                TXD
    
    
);
    
    
extern module UART_RX_FIFO #(parameter FIFO_SIZE = 4, WIDTH = 8)(
        
    input   wire                                        clk,
    input   wire                                        reset_n,
    
    input   wire                                        fifo_write,
    input   wire unsigned [WIDTH - 1 : 0]               fifo_data_in,
    
    input   wire                                        fifo_read,
    output  wire unsigned [WIDTH - 1 : 0]               fifo_top_data_out,
    
    output  logic                                       fifo_not_empty,
    output  logic                                       fifo_full,
    output  logic unsigned [$clog2(FIFO_SIZE) - 1 : 0]  fifo_count
);
    
extern module wb_Serial_8051
        #(parameter STABLE_TIME, MAX_BAUD_PERIOD, REG_ADDR_SCON, REG_ADDR_SBUF) (
    
    //=======================================================================
    // clock / reset
    //=======================================================================
        
        input  wire                                 clk,
        input  wire                                 reset_n,
    
    //=======================================================================
    // Wishbone Interface (FASM synchronous RAM dual port model)
    //=======================================================================
            
        input  wire                                 stb_i,
        input  wire                                 we_i,
        
        input  wire  unsigned [DATA_WIDTH - 1 : 0]  adr_wr_i,
        input  wire  unsigned [DATA_WIDTH - 1 : 0]  adr_rd_i,
        input  wire  unsigned [DATA_WIDTH - 1 : 0]  dat_i,
        output wire  unsigned [DATA_WIDTH - 1 : 0]  dat_o,
        output wire                                 ack_o,
    
    //=======================================================================
    // Timer Pulse Input
    //=======================================================================
        input   wire                                class_8051_unit_pulse,
        input   wire                                timer_trigger,
        
        input   wire                                UART_RXD,
        output  wire                                UART_TXD,
        
        output  wire                                SCON_TI, 
        output  wire                                SCON_RI
    
);

`endif
