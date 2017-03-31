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

`ifndef TIMER_SVH
`define TIMER_SVH


    parameter unsigned [1 : 0] TIMER_MODE_13_BIT          = 2'b00;
    parameter unsigned [1 : 0] TIMER_MODE_16_BIT          = 2'b01;
    parameter unsigned [1 : 0] TIMER_MODE_8_BIT_AUTO_LOAD = 2'b10;
    parameter unsigned [1 : 0] TIMER_MODE_SPLIT_TIMER     = 2'b11;


extern module timer (
        input   wire                                clk,
        input   wire                                reset_n,

        input   wire                                event_pulse,
        input   wire                                unit_pulse,
        input   wire unsigned [1 : 0]               timer_mode,
        input   wire unsigned [NUM_OF_INTx - 1 : 0] INTx,
        input   wire unsigned [NUM_OF_INTx - 1 : 0] GATE,
        
        input   wire                                C_T_bit,
        input   wire                                run,
        input   wire unsigned [DATA_WIDTH - 1 : 0]  TH_in,
        input   wire unsigned [DATA_WIDTH - 1 : 0]  TL_in,
        
        output  logic unsigned [DATA_WIDTH - 1 : 0] TH_out,
        output  logic unsigned [DATA_WIDTH - 1 : 0] TL_out,
        output  logic                               timer_trigger,
        output  logic                               TH_TL_update
        
);

extern module timer_unit_pulse #(parameter TIMER_UNIT_PULSE_PERIOD) (
        input   wire                                clk,
        input   wire                                reset_n,

        input   wire                                unit_period_update,
    
        input   wire unsigned [DATA_WIDTH - 1 : 0]  unit_period,
        
        input   wire                                enable,
        output  logic                               unit_pulse
);
    
extern module wb_timer_8051
        #(parameter REG_ADDR_TH, REG_ADDR_TL) (
    
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
                
        input   wire                                TMOD_C_T,
        input   wire                                TMOD_M1,
        input   wire                                TMOD_M0,
        input   wire                                TCON_TR,
        
        input   wire unsigned [NUM_OF_INTx - 1 : 0] INTx,
        input   wire unsigned [NUM_OF_INTx - 1 : 0] TMOD_GATE,
        
        input   wire                                event_pulse,
        
        output  wire                                timer_trigger
    
);

`endif
