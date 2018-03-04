/*
###############################################################################
# Copyright (c) 2018, PulseRain Technology LLC 
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


`ifndef ROTARY_ENCODER_SVH
`define ROTARY_ENCODER_SVH

`include "common.svh"

    
    
extern module rotary_encoder # (parameter COUNTER_BITS = 8, DEBOUNCE_DELAY = 100000, COUNTER_CLK_DECREASE = 1) (
    //=======================================================================
    // clock / reset
    //=======================================================================
        
    input   wire                                    clk,
    input   wire                                    reset_n,
    
    //=======================================================================
    // pins from the incremental rotary encoder 
    //=======================================================================
    
    input   wire                                    encoder_clk,
    input   wire                                    encoder_dt,
    input   wire                                    encoder_sw,
  
    //=======================================================================
    // counter value
    //=======================================================================
    input   wire                                    counter_init,
    input   wire  unsigned [COUNTER_BITS - 1 : 0]   counter_in,
    output  wire  unsigned [COUNTER_BITS - 1 : 0]   counter_out
);

extern module wb_rotary_encoder #(parameter REG_ADDR_COUNTER, COUNTER_BITS = 8, DEBOUNCE_DELAY = 100000, COUNTER_CLK_DECREASE = 1
                      ) (

        
        //=======================================================================
        // clock / reset
        //=======================================================================
        
        input   wire                                clk,
        input   wire                                reset_n,

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
        // pins from the incremental rotary encoder 
        //=======================================================================
        input   wire                                encoder_clk,
        input   wire                                encoder_dt,
        input   wire                                encoder_sw
        
);

    
`endif
