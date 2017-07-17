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


`ifndef PWM_SVH
`define PWM_SVH

`include "common.svh"

    parameter unsigned [2 : 0] PWM_SUB_ADDR_RESOLUTION_LOW = 3'b000;
    parameter unsigned [2 : 0] PWM_SUB_ADDR_RESOLUTION_HIGH  = 3'b001;
    
    parameter unsigned [2 : 0] PWM_SUB_ADDR_REG_ON  = 3'b010;
    parameter unsigned [2 : 0] PWM_SUB_ADDR_REG_OFF  = 3'b011;
    
    parameter unsigned [2 : 0] PWM_SUB_ADDR_SYNC_RESET = 3'b100;
    
    
    
extern module PWM_core  (
    //=======================================================================
    // clock / reset
    //=======================================================================
        
    input   wire                                clk,
    input   wire                                reset_n,
    
    input   wire                                sync_reset,

    //=======================================================================
    // PWM 
    //=======================================================================
    
    input   wire                                pwm_pulse,
    input   wire unsigned [7 : 0]               pwm_on_reg,
    input   wire unsigned [7 : 0]               pwm_off_reg,
  
    output  logic                               pwm_out
);
    
extern module wb_PWM #(parameter NUM_OF_PWM, 
                      REG_ADDR_CSR,
                      REG_ADDR_DATA
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
        // PWM output
        //=======================================================================
        output wire unsigned [NUM_OF_PWM - 1 : 0]    pwm_out 
        
);

    
`endif
