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



`ifndef SD_SPI_SVH
`define SD_SPI_SVH

`include "common.svh"
    
    parameter unsigned [5 : 0] SD_CMD0  = 6'h00;
    parameter unsigned [5 : 0] SD_CMD8  = 6'h08;

    parameter unsigned [1 : 0] SD_R1_R1B = 2'b00;
    parameter unsigned [1 : 0] SD_R2     = 2'b01;
    parameter unsigned [1 : 0] SD_R3_R7  = 2'b10;
    
    
    parameter unsigned [1 : 0] SD_RET_OK       = 2'b11;
    parameter unsigned [1 : 0] SD_RET_TIME_OUT = 2'b01;
    parameter unsigned [1 : 0] SD_RET_CRC_FAIL = 2'b10;
    
    
    
`endif
