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



`ifndef PS2_SVH
`define PS2_SVH

`include "common.svh"

extern module ps2_keyboard (
    //=======================================================================
    // clock / reset
    //=======================================================================
        
    input   wire                                    clk,
    input   wire                                    reset_n,
    input   wire                                    sync_reset,
    
    //=======================================================================
    // pins from the PS2 port 
    //=======================================================================
    
    input   wire                                    ps2_clk,
    input   wire                                    ps2_dat,
  
    //=======================================================================
    // output 
    //=======================================================================
    output logic                                    enable_out,
    output logic unsigned [7 : 0]                   data_out
);

`endif
