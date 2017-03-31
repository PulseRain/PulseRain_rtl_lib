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
// Remarks:
//   FASM register for Wishbone bus
//=============================================================================

`include "common.svh"
`include "FASM_register.svh"

`default_nettype none


module FASM_register 
        #(parameter REG_ADDR) (
        
    //========== INPUT ==========    
    input  wire                                 clk,
    input  wire                                 reset_n,
    
    input  wire                                 we,
    input  wire  unsigned [DATA_WIDTH - 1 : 0]  adr_wr,
    input  wire  unsigned [DATA_WIDTH - 1 : 0]  adr_rd,
    input  wire  unsigned [DATA_WIDTH - 1 : 0]  din,
    output logic unsigned [DATA_WIDTH - 1 : 0]  data_reg
);

    always_ff @(posedge clk, negedge reset_n) begin : data_reg_proc
        if (!reset_n) begin
            data_reg <= 0;
        end else if (we & (~(|(adr_wr ^ REG_ADDR)))) begin
            data_reg <= din;
        end     
    end : data_reg_proc
    
endmodule : FASM_register

`default_nettype wire
