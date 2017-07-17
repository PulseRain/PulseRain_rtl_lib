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


`include "PWM.svh"

`default_nettype none

module PWM_core  (
    //=======================================================================
    // clock / reset
    //=======================================================================
        
    input   wire                                clk,
    input   wire                                reset_n,
    
    input   wire                                sync_reset,

    //=======================================================================
    // PWM 
    //=======================================================================
    
    input   wire                                pwm_pulse,
    input   wire unsigned [7 : 0]               pwm_on_reg,
    input   wire unsigned [7 : 0]               pwm_off_reg,
  
    output  logic                               pwm_out
);
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Signals
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 
        logic                                           ctl_set_pwm_on_off;
        logic unsigned [7 : 0]                          pwm_counter;
        logic                                           ctl_load_pwm_on;
        logic                                           ctl_load_pwm_off;
        logic                                           ctl_pwm_out_high;
        logic                                           pwm_pulse_d1;
        logic                                           pwm_pulse_d2;
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // PWM
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : pwm_counter_proc
            if (!reset_n) begin
                pwm_counter <= 0;
                pwm_pulse_d1 <= 0;
                pwm_pulse_d2 <= 0;
            end else begin
                
                pwm_pulse_d1 <= pwm_pulse;
                pwm_pulse_d2 <= pwm_pulse_d1;
                
                case (1'b1) // synthesis parallel_case 
                     ctl_load_pwm_on : begin
                         pwm_counter <= pwm_on_reg;
                     end
                     
                     ctl_load_pwm_off : begin
                         pwm_counter <= pwm_off_reg;
                     end
                     
                     default : begin
                         if (pwm_pulse_d1 && pwm_counter) begin
                             pwm_counter <= pwm_counter - ($size(pwm_counter))'(1);
                         end
                     end
                endcase
            end
        end : pwm_counter_proc
            
        always_ff @(posedge clk, negedge reset_n) begin : pwm_out_proc
            if (!reset_n) begin
                pwm_out <= 0;
            end else if (sync_reset) begin
                pwm_out <= 0;
            end else if (pwm_pulse_d1) begin
                pwm_out <= ctl_pwm_out_high;
            end
        end : pwm_out_proc
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // FSM
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                
        enum {S_INIT, S_ON, S_OFF} states;
                
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
            
            ctl_load_pwm_on = 0;
            ctl_load_pwm_off = 0;
            
            ctl_pwm_out_high = 0;
                        
            case (1'b1) // synthesis parallel_case 
                
                current_state [S_INIT] : begin
                    if (pwm_on_reg) begin
                       ctl_load_pwm_on = 1'b1;
                       next_state [S_ON] = 1'b1;
                    end else begin
                       next_state [S_INIT] = 1'b1; 
                    end
                end
                
                current_state[S_ON]: begin
                    ctl_pwm_out_high = 1'b1;
                    
                    if (pwm_pulse_d2) begin
                        if (pwm_counter) begin
                            
                            next_state [S_ON] = 1'b1;
                        end else begin
                            ctl_load_pwm_off = 1'b1;
                            next_state [S_OFF] = 1'b1;
                        end
                    end else begin
                        next_state [S_ON] = 1'b1;
                    end
                end
                
                current_state[S_OFF]: begin
                    
                    if (pwm_pulse) begin
                        if (pwm_counter) begin
                            
                            next_state [S_OFF] = 1'b1;
                        end else begin
                            ctl_load_pwm_on = 1'b1;
                            next_state [S_ON] = 1'b1;
                        end
                    end else begin
                        next_state [S_OFF] = 1'b1;
                    end
                end
                    
                default: begin
                    next_state[S_INIT] = 1'b1;
                end
                
            endcase
              
        end : state_machine_comb    


endmodule : PWM_core

`default_nettype wire
