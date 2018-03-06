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

`include "PS2.svh"

`default_nettype none

module ps2_keyboard (
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

    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Signals
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        logic unsigned [3 : 0]                      ps2_clk_sr;
        logic unsigned [3 : 0]                      ps2_dat_sr;
        wire                                        ps2_clk_i;
        wire                                        ps2_dat_i;
        wire                                        ps2_clk_i_d1;
        wire                                        ps2_dat_i_d1;
        
        logic unsigned [8 : 0]                      data_and_parity;
        
        logic unsigned [3 : 0]                      counter;
        logic                                       ctl_shift_bit_in;
        logic                                       ctl_reset_counter;
        logic                                       ctl_inc_counter;
        logic                                       ctl_output_load;
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // shift register
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        always_ff @(posedge clk, negedge reset_n) begin : sr_proc
            if (!reset_n) begin
                ps2_clk_sr <= 0;
                ps2_dat_sr <= 0;
            end else begin
                ps2_clk_sr <= {ps2_clk_sr[$high(ps2_clk_sr) - 1 : 0] & ps2_clk};
                ps2_dat_sr <= {ps2_dat_sr[$high(ps2_dat_sr) - 1 : 0] & ps2_dat};
            end
        end : sr_proc
        
        assign ps2_clk_i = ps2_clk_sr [$high(ps2_clk_sr) - 1];
        assign ps2_dat_i = ps2_dat_sr [$high(ps2_dat_sr) - 1];
        
        assign ps2_clk_i_d1 = ps2_clk_sr [$high(ps2_clk_sr)];
        assign ps2_dat_i_d1 = ps2_dat_sr [$high(ps2_dat_sr)];
        

    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // data shift in
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : data_shift_in_proc
            if (!reset_n) begin
                data_and_parity <= 0;
            end else if (ctl_shift_bit_in) begin
                data_and_parity <= {ps2_dat_i, data_and_parity [$high(data_and_parity) : 1]};
            end
        end : data_shift_in_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : counter_proc
            if (!reset_n) begin
                counter <= 0;
            end else if (ctl_reset_counter) begin
                counter <= 0;
            end else if (ctl_inc_counter) begin
                counter <= counter + ($size(counter))'(1);
            end
        end : counter_proc
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // output
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : output_proc
            if (!reset_n) begin
                enable_out <= 0;
                data_out <= 0;
            end else if (ctl_output_load) begin
                enable_out <= 1'b1;
                data_out   <= data_and_parity [7 : 0];
            end else begin
                enable_out <= 0;
            end
        end : output_proc
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // FSM
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                
        enum {S_IDLE, S_START, S_DATA, S_PARITY_CHECK, S_STOP, S_OUTPUT} states = S_IDLE;
                
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
            
            ctl_shift_bit_in = 0;
            ctl_reset_counter = 0;
            ctl_inc_counter = 0;
            ctl_output_load = 0;
            
            case (1'b1) // synthesis parallel_case 
                
                current_state[S_IDLE]: begin
                    
                    ctl_reset_counter = 1'b1;
                    
                    if (ps2_clk_i) begin
                        next_state [S_IDLE] = 1'b1;
                    end else begin
                        next_state [S_START] = 1'b1;
                    end
                end
                
                current_state [S_START] : begin
                    
                    if ((~ps2_clk_i_d1) & ps2_clk_i) begin
                        if (ps2_dat_i) begin
                            next_state [S_IDLE] = 1'b1; // start bit wrong, go back to idle
                        end else begin
                            next_state [S_DATA] = 1'b1;
                        end
                    end else begin 
                        next_state [S_START] = 1'b1;
                    end
                end
                
                current_state [S_DATA] : begin
                
                    if ((~ps2_clk_i_d1) & ps2_clk_i) begin
                        ctl_inc_counter = 1'b1;
                        ctl_shift_bit_in = 1'b1;
                        
                        if (counter == 8) begin
                            next_state [S_PARITY_CHECK] = 1'b1;
                        end else begin
                            next_state [S_DATA] = 1'b1;
                        end
                    end else begin
                        next_state [S_DATA] = 1'b1;
                    end
                    
                end
                
                current_state [S_PARITY_CHECK] : begin
                    
                    if (^data_and_parity) begin  // odd parity pass
                        next_state [S_STOP] = 1'b1;
                    end else begin
                        next_state [S_IDLE] = 1; // odd parity fail
                    end
                    
                end
                
                current_state [S_STOP] : begin
                    
                    if ((~ps2_clk_i_d1) & ps2_clk_i) begin
                        if (ps2_dat_i) begin
                            next_state [S_OUTPUT] = 1'b1;  // got stop bit and valid data
                        end else begin
                            next_state [S_IDLE] = 1'b1; // stop bit fail
                        end
                    end else begin
                        next_state [S_STOP] = 1;
                    end
                    
                end
                
                current_state [S_OUTPUT] : begin
                    ctl_output_load = 1'b1;
                    next_state [S_IDLE] = 1'b1;                   
                end
                
                default: begin
                    next_state[S_IDLE] = 1'b1;
                end
                
            endcase
              
        end : state_machine_comb    

endmodule : ps2_keyboard

`default_nettype wire
