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
//   timer for FP51 
//=============================================================================

`include "common.svh"
`include "timer.svh"

`default_nettype none

module timer (
        
        //========== INPUT ==========
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
        
        //========== OUTPUT ==========
        output  logic unsigned [DATA_WIDTH - 1 : 0] TH_out,
        output  logic unsigned [DATA_WIDTH - 1 : 0] TL_out,
        output  logic                               timer_trigger,
        output  logic                               TH_TL_update
    
);
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Signals
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        logic                                   timer_enable;
        wire  unsigned [NUM_OF_INTx - 1 : 0]    gate_enable;
        logic unsigned [15 : 0]                 counter16, counter16_init_value;
        logic unsigned [7 : 0]                  counter8, counter8_init_value;
        logic unsigned [3 : 0]                  timer_inc_step;
        logic unsigned [2 : 0]                  event_pulse_sr;
        logic                                   timer_pulse;
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // timer enable
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        assign gate_enable = (~GATE) | (GATE & INTx);
        
        always_ff @(posedge clk, negedge reset_n) begin : timer_enable_proc
            if (!reset_n) begin
                timer_enable <= 0;
            end else begin
                timer_enable <= run & (&gate_enable);
            end
        end : timer_enable_proc

    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // shift register for event pulse, for meta-stability
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : event_pulse_sr_proc
            if (!reset_n) begin
                event_pulse_sr <= 0;
            end else begin
                event_pulse_sr <= {event_pulse_sr [$high(event_pulse_sr) - 1 : 0], event_pulse};
            end
        end : event_pulse_sr_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : timer_pulse_proc
            if (!reset_n) begin
                timer_pulse <= 0;
            end else if (C_T_bit) begin
                timer_pulse <= (~event_pulse_sr [$high(event_pulse_sr)]) 
                                & event_pulse_sr [$high(event_pulse_sr) - 1];
            end else begin
                timer_pulse <= unit_pulse;
            end
        end : timer_pulse_proc
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // timer counter 16 bit
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : timer_counter16_proc
            if (!reset_n) begin
                counter16            <= 0;
                counter16_init_value <= 0;
                timer_inc_step       <= 0;
            end else if ((!timer_enable) && run) begin
                counter16 [15 : 8]            <= TH_in;
                counter16_init_value [15 : 8] <= TH_in; 
                
                // 13 bit mode is not supported
                counter16 [7 : 0]            <= TL_in;
                counter16_init_value [7 : 0] <= TL_in;
                timer_inc_step               <= 4'b0001;
                
            end else if (timer_enable & timer_pulse) begin
                if (counter16 == 16'hFFFF) begin
                    counter16 <= counter16_init_value;
                end else begin
                    counter16 <= counter16 + {12'd0, timer_inc_step};
                end
            end
        end : timer_counter16_proc
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // timer counter 8 bit (split timer mode is not supported)
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : timer_counter8_proc
            if (!reset_n) begin
                counter8            <= 0;
                counter8_init_value <= 0;
            end else if ((!timer_enable) && run) begin
                counter8            <= TL_in;
                counter8_init_value <= TH_in;
            end else if (timer_enable & timer_pulse) begin
                if (counter8 == 8'hFF) begin
                    counter8 <= counter8_init_value;
                end else begin
                    counter8 <= counter8 + ($size(counter8))'(1);
                end
            end
        end : timer_counter8_proc
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // timer trigger, only 16 bit mode and 8 bit auto load mode are supported
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : timer_trigger_proc
            if (!reset_n) begin
                timer_trigger <= 0;
            end else begin
                if  ( ((timer_mode == TIMER_MODE_16_BIT) && 
                       timer_enable && 
                      (counter16 == 16'hFFFF)) 
                         || 
                     ((timer_mode == TIMER_MODE_8_BIT_AUTO_LOAD) && 
                     timer_enable && 
                     (counter8 == 8'hFF))) begin
                     timer_trigger <= timer_pulse;
                end else begin
                     timer_trigger <= 1'b0;                 
                end
            end
        end : timer_trigger_proc
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // TH / TL update
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : TH_TL_update_proc
            if (!reset_n) begin
                TH_TL_update <= 0;
                TH_out <= 0;
                TL_out <= 0;
            end else begin
                TH_TL_update <= timer_enable;
                
                if (timer_mode == TIMER_MODE_16_BIT) begin
                    TH_out <= counter16 [15 : 8];
                    TL_out <= counter16 [7 : 0];
                end else begin
                    TL_out <= counter8;
                end
            end
        end : TH_TL_update_proc
        
endmodule : timer

`default_nettype wire
