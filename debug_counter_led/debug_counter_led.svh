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

`ifndef DEBUG_COUNTER_LED_SVH
`define DEBUG_COUNTER_LED_SVH

extern module debug_counter_led
        #(parameter REG_ADDR) (
        
    //========== INPUT ==========
    input  wire                                 clk,
    input  wire                                 reset_n,
    
    input  wire                                 stb_i,
    input  wire                                 we_i,
    
    input  wire  unsigned [DATA_WIDTH - 1 : 0]  adr_wr_i,
    input  wire  unsigned [DATA_WIDTH - 1 : 0]  adr_rd_i,
    input  wire  unsigned [DATA_WIDTH - 1 : 0]  dat_i,
    
    //========== OUTPUT ==========
    output wire  unsigned [DATA_WIDTH - 1 : 0]  dat_o,
    output wire                                 ack_o,
    
    output logic                                led,
    output logic                                non_zero_pulse,
    output logic                                dog_bite
);

`endif
