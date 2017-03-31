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


//=============================================================================
// References:
//   Wishbone wrapper for FP51 timer
//=============================================================================

`include "common.svh"

`default_nettype none

module wb_timer_8051
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

    //=======================================================================
    // Signals 
    //=======================================================================
        logic   unsigned [DATA_WIDTH - 1 : 0]           reg_TH;
        logic   unsigned [DATA_WIDTH - 1 : 0]           reg_TL;
        
        wire    unsigned [DATA_WIDTH - 1 : 0]           TH_value_out;
        wire    unsigned [DATA_WIDTH - 1 : 0]           TL_value_out;
        
        wire                                            TH_TL_update;
            
    //=======================================================================
    // register 
    //=======================================================================
        
        // register TH
        always_ff @(posedge clk, negedge reset_n) begin : TH_reg_proc
            if (!reset_n) begin
                reg_TH <= 0;
            end else if (stb_i && we_i && (adr_wr_i == REG_ADDR_TH)) begin
                reg_TH <= dat_i;
            end else if (TH_TL_update) begin
                reg_TH <= TH_value_out;
            end
        end : TH_reg_proc
        
        // register TL
        always_ff @(posedge clk, negedge reset_n) begin : TL_reg_proc
            if (!reset_n) begin
                reg_TL <= 0;
            end else if (stb_i && we_i && (adr_wr_i == REG_ADDR_TL)) begin
                reg_TL <= dat_i;
            end else if (TH_TL_update) begin
                reg_TL <= TL_value_out;
            end
        end : TL_reg_proc
        
        assign ack_o = stb_i;
        
        assign dat_o = (adr_rd_i == REG_ADDR_TH) ? reg_TH : reg_TL; 
            
    //=======================================================================
    // timer 
    //=======================================================================
    
        timer timer_i (.*,
            .event_pulse (event_pulse),
            .unit_pulse (class_8051_unit_pulse),
            .timer_mode ({TMOD_M1, TMOD_M0}),
            .INTx (INTx),
            .GATE (TMOD_GATE),
            .C_T_bit (TMOD_C_T),
            .run (TCON_TR),
            
            .TH_in (reg_TH),
            .TL_in (reg_TL),
            
            .TH_out (TH_value_out),
            .TL_out (TL_value_out),
            
            .timer_trigger (timer_trigger),
            .TH_TL_update (TH_TL_update));  

endmodule : wb_timer_8051
    
`default_nettype wire
