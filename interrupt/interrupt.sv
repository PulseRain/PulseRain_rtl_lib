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
// Remarks:
//   interrupt controller that supports both level and pulse interrupt.
//=============================================================================

`include "interrupt.svh"

`default_nettype none

module interrupt
      #(parameter NUM_OF_INT)(
      
      //========== INPUT ==========
    
        input   wire                                clk,
        input   wire                                reset_n,
        input   wire                                ret_int,
        input   wire                                global_int_enable,
        input   wire unsigned [NUM_OF_INT - 1 : 0]  int_enable_mask,
        input   wire unsigned [NUM_OF_INT - 1 : 0]  int_priority_mask,
        input   wire unsigned [NUM_OF_INT - 1 : 0]  int_level1_pulse0,
                
        input   wire unsigned [NUM_OF_INT - 1 : 0]  int_pins,
        
      //========== OUTPUT ==========
        output  logic unsigned [7 : 0]              int_addr,
        output  logic                               int_gen
);
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Signals
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        logic  unsigned [NUM_OF_INT - 1 : 0]       int_raw_reg;
        logic  unsigned [NUM_OF_INT - 1 : 0]       active_int_mask, active_int_mask_save;
        logic                                      current_int_priority;
        logic  unsigned [NUM_OF_INT - 1 : 0]       int_pins_d1;
       // logic                                      global_int_enable_d1;
        logic                                      ret_int_d1;
        
        wire   unsigned [NUM_OF_INT - 1 : 0]       int_raw_reg_enable_masked;
        wire   unsigned [NUM_OF_INT - 1 : 0]       int_raw_reg_enable_priority_masked;
        
        logic  unsigned [$clog2(NUM_OF_INT) - 1 : 0]    ctl_ISR_addr;
        logic                                           ctl_low_priority_int_gen;
        logic                                           ctl_high_priority_int_gen;
        wire                                            sync_reset;
        logic  unsigned [7 : 0]                         int_vector [0 : NUM_OF_INT - 1] /* synthesis romstyle = "logic" */ ; 
		  wire														  int_vector_we;
		  									                 
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // interrupt vector
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
         initial begin : rom_content_proc
            int_vector [0] <= 8'h03;  // External 0 
            int_vector [1] <= 8'h0B;  // Timer 0
            int_vector [2] <= 8'h13;  // External 1
            int_vector [3] <= 8'h1B;  // Timer 1
            int_vector [4] <= 8'h23;  // Serial
            int_vector [5] <= 8'h2B;  // ADC
            int_vector [6] <= 8'h33;  // CODEC
            
         end
			
			//--------------------------------------------------------------------
			// The following non-sense is just to avoid a possible warning 
			// in Quartus II
			//--------------------------------------------------------------------
			
				assign int_vector_we = 0;
				
				always_ff @(posedge clk) begin
					if (int_vector_we) begin
						int_vector[0] <= 0;
					end
				end
         
			//====================================================================
			
			
         always_ff @(posedge clk, negedge reset_n) begin : int_addr_proc
            if (!reset_n) begin
                int_addr <= 0;
                int_gen  <= 0;
            end else if (ctl_low_priority_int_gen | ctl_high_priority_int_gen) begin
                int_addr <= int_vector [ctl_ISR_addr];
                int_gen  <= 1'b1;
            end else begin
                int_gen  <= 0;
            end
         end : int_addr_proc
         
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // interrupt log
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        genvar i;
        generate
            for (i = 0; i < NUM_OF_INT; i = i + 1) begin : int_log_gen 
                always_ff @(posedge clk, negedge reset_n) begin : int_log_proc
                    if (!reset_n) begin
                        int_raw_reg [i] <= 0;
                    end else if (sync_reset) begin
                        int_raw_reg [i] <= 0;
                    end else if (int_level1_pulse0[i]) begin
                        int_raw_reg [i] <= int_pins [i];
                    end else begin
                        if (int_pins [i] & (~int_pins_d1[i])) begin
                            int_raw_reg [i] <= 1'b1;
                        end else if ((ret_int & active_int_mask [i])) begin
                            int_raw_reg [i] <= 1'b0;
                        end
                    end
                end : int_log_proc
            end : int_log_gen
        endgenerate
            
        always_ff @(posedge clk, negedge reset_n) begin : active_int_mask_proc
            if (!reset_n) begin
                active_int_mask <= 0;
            end else if (sync_reset) begin
                active_int_mask <= 0;
            end else if (ctl_low_priority_int_gen | ctl_high_priority_int_gen) begin
                active_int_mask <= ($size(active_int_mask))'(1 << ctl_ISR_addr);
            end else if (ret_int) begin
                active_int_mask <= active_int_mask_save & {(NUM_OF_INT){current_int_priority}};
            end 
        end : active_int_mask_proc
            
        always_ff @(posedge clk, negedge reset_n) begin : active_int_mask_save_proc
            if (!reset_n) begin
                active_int_mask_save <= 0;
            end else if (sync_reset | ctl_low_priority_int_gen | (ret_int & (~current_int_priority))) begin
                active_int_mask_save <= 0;
            end else if (ctl_high_priority_int_gen) begin
                active_int_mask_save <= active_int_mask;
            end
        end : active_int_mask_save_proc
        
        
        always_ff @(posedge clk, negedge reset_n) begin : int_pins_delay_proc
            if (!reset_n) begin
                int_pins_d1 <= 0;
           //     global_int_enable_d1 <= 0;
                ret_int_d1 <= 0;
            end else begin
                int_pins_d1 <= int_pins;
            //    global_int_enable_d1 <= global_int_enable;
                ret_int_d1 <= ret_int;
            end
        end : int_pins_delay_proc

        //==assign sync_reset = global_int_enable_d1 & (~global_int_enable);
        assign sync_reset = 0;
        
        assign int_raw_reg_enable_masked = int_raw_reg & int_enable_mask;
        assign int_raw_reg_enable_priority_masked = int_raw_reg_enable_masked & int_priority_mask;
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // current interrupt priority
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin 
            if (!reset_n) begin
                current_int_priority <= 0;
            end else if (sync_reset) begin
                current_int_priority <= 0;
            end else if (ctl_high_priority_int_gen) begin
                current_int_priority <= 1'b1;
            end else if (ctl_low_priority_int_gen || (ret_int_d1 && (!int_raw_reg_enable_priority_masked))) begin
                current_int_priority <= 0;
            end
        end
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // FSM
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                
        enum {S_IDLE, S_CHECK_PRIORITY, S_INT_LOCATE_LOW, S_INT_LOCATE_HIGH, 
              S_DELAY_EXIT, S_DELAY_EXIT2, S_DELAY_EXIT3} states = S_IDLE;
                
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
            
            ctl_ISR_addr = 0;
            
            ctl_low_priority_int_gen  = 0;
            ctl_high_priority_int_gen = 0;
        
            case (1'b1) // synthesis parallel_case 
                
                current_state[S_IDLE]: begin
                    if (global_int_enable && (int_enable_mask & int_raw_reg & (~active_int_mask))) begin
                        next_state [S_CHECK_PRIORITY] = 1'b1;
                    end else begin
                        next_state [S_IDLE] = 1'b1;
                    end
                end
                
                current_state [S_CHECK_PRIORITY] : begin
                    if (!active_int_mask) begin
                        if (int_enable_mask & int_raw_reg & int_priority_mask) begin
                            next_state [S_INT_LOCATE_HIGH] = 1'b1;
                        end else begin
                            next_state [S_INT_LOCATE_LOW] = 1'b1;
                        end
                    end else if (current_int_priority) begin
                        next_state [S_IDLE] = 1'b1;
                    end else if (int_enable_mask & int_raw_reg & int_priority_mask) begin
                        next_state [S_INT_LOCATE_HIGH] = 1'b1;
                    end else begin
                        next_state [S_IDLE] = 1'b1;
                    end
                end
                
                current_state [S_INT_LOCATE_LOW] : begin
                    next_state [S_DELAY_EXIT] = 1;
                    for (int i = NUM_OF_INT - 1; i >= 0; i = i - 1) begin
                        if (int_raw_reg_enable_masked[i]) begin
                            ctl_ISR_addr = ($size(ctl_ISR_addr))'(i);
                            ctl_low_priority_int_gen = 1'b1;
                        end
                    end
                end
                
                current_state [S_INT_LOCATE_HIGH] : begin
                    next_state [S_DELAY_EXIT] = 1;
                    for (int i = NUM_OF_INT - 1; i >= 0; i = i - 1) begin
                        if (int_raw_reg_enable_priority_masked[i]) begin
                            ctl_ISR_addr = ($size(ctl_ISR_addr))'(i);
                            ctl_high_priority_int_gen = 1'b1;
                        end
                    end
                end
                
                current_state [S_DELAY_EXIT] : begin
                    next_state[S_DELAY_EXIT2] = 1'b1;
                end
                
                current_state [S_DELAY_EXIT2] : begin
                    next_state [S_DELAY_EXIT3] = 1'b1;  
                end
                
                current_state [S_DELAY_EXIT3] : begin
                    next_state[S_IDLE] = 1'b1;
                end
                
                default: begin
                    next_state[S_IDLE] = 1'b1;
                end
                
            endcase
              
        end : state_machine_comb    
    
    
endmodule : interrupt

`default_nettype wire
