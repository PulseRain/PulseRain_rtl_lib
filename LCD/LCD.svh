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



`ifndef LCD_SVH
`define LCD_SVH

`include "common.svh"


extern module ST7735R # (parameter DIV_COUNTER_BITS = 4) (
    //=======================================================================
    // clock / reset
    //=======================================================================
        
    input   wire                                    clk,
    input   wire                                    reset_n,
    
    input   wire                                    sync_reset,
    
    //=======================================================================
    // data input
    //=======================================================================
    input   wire                                    data_load,
    input   wire unsigned [7 : 0]                   data,
    
    //=======================================================================
    // SDA/SCL
    //=======================================================================
   
    output logic                                    csx,
    output wire                                     sda, 
    output logic                                    scl,
    
    //=======================================================================
    // done
    //=======================================================================
    output logic                                    done
);


`endif
