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
//   Wishbone wrapper for FASM register
//=============================================================================

`include "common.svh"
`include "FASM_register.svh"

`default_nettype none

module wb_register
        #(parameter REG_ADDR) (
        
    input  wire                                 clk,
    input  wire                                 reset_n,
    
    input  wire                                 stb_i,
    input  wire                                 we_i,
    
    input  wire  unsigned [DATA_WIDTH - 1 : 0]  adr_wr_i,
    input  wire  unsigned [DATA_WIDTH - 1 : 0]  adr_rd_i,
    input  wire  unsigned [DATA_WIDTH - 1 : 0]  dat_i,
    output wire  unsigned [DATA_WIDTH - 1 : 0]  dat_o,
    output wire                                 ack_o
);
    
    FASM_register #(.REG_ADDR (REG_ADDR)) FASM_register_i (.*,
            .we (stb_i & we_i),
            .adr_wr (adr_wr_i),
            .adr_rd (adr_rd_i),
            .din (dat_i),
            .data_reg (dat_o));
    
    assign ack_o = stb_i;
    
endmodule : wb_register

`default_nettype wire
