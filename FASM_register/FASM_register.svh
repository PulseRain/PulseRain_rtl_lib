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

`ifndef FASM_REGISTER_SVH
`define FASM_REGISTER_SVH

extern module wb_register
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
    
extern module FASM_register 
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


`endif


