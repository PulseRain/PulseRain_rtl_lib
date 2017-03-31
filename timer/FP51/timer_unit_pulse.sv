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
//   module to generate timed pulse
//=============================================================================

`include "common.svh"
`include "timer.svh"

`default_nettype none

module timer_unit_pulse #(parameter TIMER_UNIT_PULSE_PERIOD) (
        input   wire                                clk,
        input   wire                                reset_n,

        input   wire                                unit_period_update,
    
        input   wire unsigned [DATA_WIDTH - 1 : 0]  unit_period,
        
        input   wire                                enable,
        output  logic                               unit_pulse
);
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Signals
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        logic  unsigned [DATA_WIDTH - 1 : 0]       unit_period_reg = 8'(TIMER_UNIT_PULSE_PERIOD);
        logic  unsigned [DATA_WIDTH - 1 : 0]       counter;
        wire   unsigned [DATA_WIDTH - 1 : 0]       counter_plus_1;
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Pulse Generator
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : unit_period_reg_proc
            if (!reset_n) begin
                unit_period_reg <= 8'(TIMER_UNIT_PULSE_PERIOD);
            end else if (unit_period_update) begin
                unit_period_reg <= unit_period;
            end
        end : unit_period_reg_proc
    
        assign counter_plus_1 = counter + ($size(counter))'(1);
        
        always_ff @(posedge clk, negedge reset_n) begin : counter_proc
            if (!reset_n) begin
                counter <= 0;
                unit_pulse <= 0;
            end else if (unit_period_update) begin
                counter <= 0;
                unit_pulse <= 0;
            end else if (enable) begin
                if (counter_plus_1 == unit_period_reg) begin
                    counter <= 0;
                    unit_pulse <= 1'b1;
                end else begin
                    counter <= counter + ($size(counter))'(1);
                    unit_pulse <= 0;
                end
            end
        end : counter_proc
        
endmodule : timer_unit_pulse

`default_nettype wire
