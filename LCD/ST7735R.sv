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

`include "LCD.svh"

`default_nettype none

module ST7735R # (parameter DIV_COUNTER_BITS = 3) (
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


    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Signals
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        logic unsigned [DIV_COUNTER_BITS - 1 : 0]       counter;
        logic                                           pos_pulse;
        logic                                           neg_pulse;
        logic unsigned [7 : 0]                          data_shift_sr;
        logic unsigned [3 : 0]                          shift_counter;
        
        logic                                           ctl_data_shift;
        logic                                           ctl_csx;
        logic                                           ctl_dec_shift_counter;
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // counter
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
       
        always_ff @(posedge clk, negedge reset_n) begin : counter_proc
            if (!reset_n) begin
                counter <= 0;
            end else if (sync_reset) begin
                counter <= 0;
            end else begin
                counter <= counter + ($size(counter))'(1);
            end 
        end : counter_proc
       
        always_ff @(posedge clk, negedge reset_n) begin : pos_pulse_proc
            if (!reset_n) begin
                pos_pulse <= 0;
            end else if (counter == 1) begin
                pos_pulse <= 1'b1;
            end else begin
                pos_pulse <= 0;
            end
        end : pos_pulse_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : neg_pulse_proc
            if (!reset_n) begin
                neg_pulse <= 0;
            end else if (counter == (2**(DIV_COUNTER_BITS - 1))) begin
                neg_pulse <= 1'b1;
            end else begin
                neg_pulse <= 0;
            end
        end : neg_pulse_proc


    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // data_shift_sr
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : data_shift_sr_proc
            if (!reset_n) begin
                data_shift_sr <= 0;
            end else if (data_load) begin
                data_shift_sr <= data;
            end else if (ctl_data_shift) begin
                data_shift_sr <= {data_shift_sr [$high(data_shift_sr) - 1 : 0], 1'b0};
            end 
        end : data_shift_sr_proc


    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // csx
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : csx_proc
            if (!reset_n) begin
                csx <= 0;
            end else begin
                csx <= ctl_csx;
            end
        end : csx_proc
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // shift counter
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : shift_counter_proc
            if (!reset_n) begin
                shift_counter <= 0;
            end else if (sync_reset | data_load) begin
                shift_counter <= ($size(shift_counter))'(8);
            end else if (ctl_dec_shift_counter) begin
                shift_counter <= shift_counter - ($size(shift_counter))'(1);
            end
        end : shift_counter_proc
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // output
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        assign sda = data_shift_sr [$high(data_shift_sr)] | csx;
        
        always_ff @(posedge clk, negedge reset_n) begin : scl_proc
            if (!reset_n) begin
                scl <= 0;
            end else if (neg_pulse | csx) begin
                scl <= 0;
            end else if (pos_pulse) begin
                scl <= 1'b1;
            end
        end : scl_proc
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // FSM
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                
        enum {S_IDLE, S_WAIT_NEG_PULSE, S_DATA_SHIFT, S_DONE} states = S_IDLE;
                
        localparam FSM_NUM_OF_STATES = states.num();
        logic [FSM_NUM_OF_STATES - 1:0] current_state = 0, next_state;
                
        // Declare states
        always_ff @(posedge clk, negedge reset_n) begin : state_machine_reg
            if (!reset_n) begin
                current_state <= 0;
            end else if (sync_reset) begin 
                current_state <= 0;
            end else begin
                current_state <= next_state;
            end
        end : state_machine_reg
            
        // state cast for debug, one-hot translation, enum value can be shown in the simulation in this way
        // Hopefully, synthesizer will optimize out the "states" variable
            
        // synthesis translate_off
        ///////////////////////////////////////////////////////////////////////
            always_comb begin : state_cast_for_debug
                for (int i = 0; i < FSM_NUM_OF_STATES; ++i) begin
                    if (current_state[i]) begin
                        $cast(states, i);
                    end
                end
            end : state_cast_for_debug
        ///////////////////////////////////////////////////////////////////////
        // synthesis translate_on   
            
        // FSM main body
        always_comb begin : state_machine_comb

            next_state = 0;
            
            ctl_data_shift = 0;
            ctl_csx = 1'b1;
            ctl_dec_shift_counter = 0;
            
            done = 0;
            
            case (1'b1) // synthesis parallel_case 
                
                current_state[S_IDLE]: begin
                    if (data_load) begin
                        next_state [S_WAIT_NEG_PULSE] = 1'b1;
                    end else begin
                        next_state [S_IDLE] = 1'b1;
                    end
                end
                
                current_state [S_WAIT_NEG_PULSE] : begin
                    
                    if (neg_pulse) begin
                        next_state [S_DATA_SHIFT] = 1'b1;
                        ctl_csx = 1'b0;
                    end else begin
                        next_state [S_WAIT_NEG_PULSE] = 1'b1;
                    end 
                end
                
                current_state [S_DATA_SHIFT] : begin
                    ctl_csx = 1'b0;
                
                    ctl_dec_shift_counter = pos_pulse;
                    
                    ctl_data_shift = neg_pulse;
                    
                    if (!shift_counter) begin
                        next_state [S_DONE] = 1'b1;
                    end else begin
                        next_state [S_DATA_SHIFT] = 1'b1;
                    end
                    
                end
                
                current_state [S_DONE] : begin
                    
                    ctl_csx = 1'b0;
                    
                    if (neg_pulse) begin
                        done = 1'b1;
                        next_state [S_IDLE] = 1'b1;
                    end else begin
                        next_state [S_DONE] = 1'b1;
                    end
                end
                
                default: begin
                    next_state[S_IDLE] = 1'b1;
                end
                
            endcase
              
        end : state_machine_comb    
    
endmodule : ST7735R

`default_nettype wire
