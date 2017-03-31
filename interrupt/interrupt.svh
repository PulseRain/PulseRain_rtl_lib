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

`ifndef INTERRUPT_SVH
`define INTERRUPT_SVH

extern module interrupt
      #(parameter NUM_OF_INT)(
      
        input   wire                                clk,
        input   wire                                reset_n,
        input   wire                                ret_int,
        input   wire                                global_int_enable,
        input   wire unsigned [NUM_OF_INT - 1 : 0]  int_enable_mask,
        input   wire unsigned [NUM_OF_INT - 1 : 0]  int_priority_mask,
        input   wire unsigned [NUM_OF_INT - 1 : 0]  int_level1_pulse0,
                
        input   wire unsigned [NUM_OF_INT - 1 : 0]  int_pins,
        
        output  logic unsigned [7 : 0]              int_addr,
        output  logic                               int_gen
        
);

`endif
