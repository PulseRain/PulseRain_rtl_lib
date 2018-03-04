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

`include "rotary_encoder.svh"

`default_nettype none

module rotary_encoder # (parameter COUNTER_BITS = 8, DEBOUNCE_DELAY = 100000, COUNTER_CLK_DECREASE = 1) (
    //=======================================================================
    // clock / reset
    //=======================================================================
        
    input   wire                                    clk,
    input   wire                                    reset_n,
    
    //=======================================================================
    // pins from the incremental rotary encoder 
    //=======================================================================
    
    input   wire                                    encoder_clk,
    input   wire                                    encoder_dt,
    input   wire                                    encoder_sw,
  
    //=======================================================================
    // counter value
    //=======================================================================
    input   wire                                    counter_init,
    input   wire  unsigned [COUNTER_BITS - 1 : 0]   counter_in,
    output  wire  unsigned [COUNTER_BITS - 1 : 0]   counter_out
);


    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Signals
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        wire                                        encoder_clk_i;
        wire                                        encoder_dt_i;
        wire                                        encoder_sw_i;
        
        logic                                       encoder_clk_i_d1;
        logic unsigned [COUNTER_BITS - 1 : 0]       counter;                 
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // button debouncer
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
            switch_debouncer   #(.TIMER_VALUE(DEBOUNCE_DELAY)) encoder_clk_debounce_i (
                .clk (clk),
                .reset_n (reset_n),  
                .data_in (encoder_clk),
                .data_out (encoder_clk_i)
            );
    
            switch_debouncer   #(.TIMER_VALUE(DEBOUNCE_DELAY)) encoder_dt_debounce_i (
                .clk (clk),
                .reset_n (reset_n),  
                .data_in (encoder_dt),
                .data_out (encoder_dt_i)
            );

            switch_debouncer   #(.TIMER_VALUE(DEBOUNCE_DELAY)) encoder_sw_debounce_i (
                            .clk (clk),
                            .reset_n (reset_n),  
                            .data_in (encoder_sw),
                            .data_out (encoder_sw_i)
            );

    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // delay
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
            always_ff @(posedge clk, negedge reset_n) begin : delay_proc
                if (!reset_n) begin
                    encoder_clk_i_d1 <= 0;
                end else begin
                    encoder_clk_i_d1 <= encoder_clk_i;
                end
            end : delay_proc
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // counter
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
            always_ff @(posedge clk, negedge reset_n) begin : counter_proc
                if (!reset_n) begin
                    counter <= 0;
                end else begin
                    if ((counter_init) || (!encoder_sw_i)) begin
                        counter <= counter_in;
                    end else if ((~encoder_clk_i_d1) | encoder_clk_i) begin
                        if (encoder_dt_i) begin
                            counter <= counter + (COUNTER_BITS)'(COUNTER_CLK_DECREASE);
                        end else begin
                            counter <= counter - (COUNTER_BITS)'(COUNTER_CLK_DECREASE);
                        end
                    end
                end
            
            end : counter_proc
 
endmodule : rotary_encoder


`default_nettype wire

