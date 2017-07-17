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
//   [1] 23A1024/23LC1024, 1Mbit SPI Serial SRAM with SDI and SQI Interface
//       Microchip Technology, Inc. 2011
//=============================================================================


`include "M23XX1024.svh"

`default_nettype none

module M23XX1024 #(parameter CLK_SCK_RATIO = 6) (
    //=======================================================================
    // clock / reset
    //=======================================================================
        
    input   wire                                clk,
    input   wire                                reset_n,
    
    input   wire                                sync_reset,

    //=======================================================================
    // host interface
    //=======================================================================
    
    input   wire                                instruction_start,
    input   wire unsigned [7 : 0]               instruction,
    input   wire unsigned [23 : 0]              address,
    input   wire unsigned [7 : 0]               write_data,
    
    output  logic                               write_data_grasp,
    
    output  logic                               read_data_enable_out,
    output  logic unsigned [7 : 0]              read_data,
    
    //=======================================================================
    // device interface
    //=======================================================================
    
    input   wire                                mem_so,
    output  logic                               mem_si,
    output  wire                                mem_hold_n,
    output  wire                                mem_cs_n, 
    output  logic                               mem_sck
);
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Signals
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        logic                                           ctl_cs_low;
        logic                                           ctl_cs_high;
        logic                                           cs_n = 1'b1;
        logic                                           sck_enable;
        logic                                           ctl_sck_on;
        logic                                           ctl_sck_off;
        logic unsigned [$clog2(CLK_SCK_RATIO) - 1 : 0]  sck_counter;
        logic                                           sck_pulse;
        
        logic unsigned [7 : 0]                          instruction_reg;
        logic unsigned [23 : 0]                         address_reg;
        logic unsigned [7 : 0]                          write_data_reg;
        
        logic unsigned [3 : 0]                          shift_counter;
        logic                                           ctl_shift_counter_load;
        
        logic                                           ctl_shift_inst_reg;
        logic                                           ctl_shift_addr_reg;
        logic                                           ctl_shift_write_data_reg;
        
        logic                                           has_address_stage;
        logic                                           has_data_write_stage;
        logic                                           has_data_read_stage;
        
        logic                                           ctl_reset_stage_register;
        logic                                           ctl_has_address_stage;
        logic                                           ctl_has_data_write_stage;
        logic                                           ctl_has_data_read_stage;
        
        logic                                           ctl_load_mem_mode;
        logic                                           ctl_write_data_grasp;
        logic                                           ctl_shift_read_data;
        logic unsigned [7 : 0]                          data_read_reg;
        
        logic unsigned [1 : 0]                          mem_mode = M23XX1024_SEQ_MODE;
        
        logic                                           ctl_read_data_enable_out;
        logic                                           ctl_read_data_enable_out_d1;
        
        localparam int CLK_SCK_RATIO_DIV_2 = CLK_SCK_RATIO / 2;

    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // mem hold, always no hold
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        assign mem_hold_n = 1'b1;
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // registers and shift
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : instruction_reg_proc
            if (!reset_n) begin
                instruction_reg <= 0;
            end else if (instruction_start) begin
                instruction_reg <= instruction;
            end else if (ctl_shift_inst_reg & sck_pulse) begin
                instruction_reg <= instruction_reg << 1;
            end
        end : instruction_reg_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : address_reg_proc
            if (!reset_n) begin
                address_reg <= 0;
            end else if (instruction_start) begin
                address_reg <= address;
            end else if (ctl_shift_addr_reg & sck_pulse) begin
                address_reg <= address_reg << 1;
            end
        end : address_reg_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : write_data_reg_proc
            if (!reset_n) begin
                write_data_reg <= 0;
            end else if (instruction_start | ctl_write_data_grasp) begin
                write_data_reg <= write_data;
            end else if (ctl_shift_write_data_reg & sck_pulse) begin
                write_data_reg <= write_data_reg << 1;
            end
        end : write_data_reg_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : write_data_grasp_proc
            if (!reset_n) begin
                write_data_grasp <= 0;
            end else begin
                write_data_grasp <= ctl_write_data_grasp | instruction_start;
            end
        end : write_data_grasp_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : data_read_reg_proc
            if (!reset_n) begin
                data_read_reg <= 0;
            end else if (ctl_shift_read_data & sck_pulse) begin
                data_read_reg <= {data_read_reg[$high(data_read_reg) - 1 : 0], mem_so};
            end
        end : data_read_reg_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : read_data_proc
            if (!reset_n) begin
                read_data <= 0;
                read_data_enable_out <= 0;
                ctl_read_data_enable_out_d1 <= 0;
            end else begin
                ctl_read_data_enable_out_d1 <= ctl_read_data_enable_out;
                read_data_enable_out <= ctl_read_data_enable_out_d1;
                
                if (ctl_read_data_enable_out_d1) begin
                    read_data <= data_read_reg;
                end
            end
        end : read_data_proc
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // determine address, r/w stage
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : has_address_stage_proc
            if (!reset_n) begin
                has_address_stage <= 0;
            end else if (ctl_reset_stage_register) begin
                has_address_stage <= 0;
            end else if (ctl_has_address_stage) begin
                has_address_stage <= 1'b1;
            end
        end : has_address_stage_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : has_data_write_stage_proc
            if (!reset_n) begin
                has_data_write_stage <= 0;
            end else if (ctl_reset_stage_register) begin
                has_data_write_stage <= 0;  
            end else if (ctl_has_data_write_stage) begin
                has_data_write_stage <= 1'b1;
            end
        end : has_data_write_stage_proc

        always_ff @(posedge clk, negedge reset_n) begin : has_data_read_stage_proc
            if (!reset_n) begin
                has_data_read_stage <= 0;
            end else if (ctl_reset_stage_register) begin
                has_data_read_stage <= 0;
            end else if (ctl_has_data_read_stage) begin
                has_data_read_stage <= 1'b1;
            end
            
        end : has_data_read_stage_proc
                            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // SI/SO
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : sio_data_to_mem_proc
            if (!reset_n) begin
                mem_si <= 0;
            end else if (ctl_shift_inst_reg) begin
                mem_si <= instruction_reg[7];
            end else if (ctl_shift_addr_reg) begin
                mem_si <= address_reg[23];
            end else if (ctl_shift_write_data_reg) begin
                mem_si <= write_data_reg[7];
            end
        end : sio_data_to_mem_proc
                    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // shift_counter
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : shift_counter_proc
            if (!reset_n) begin
                shift_counter <= 0;
            end else if (ctl_shift_counter_load) begin
                shift_counter <= ($size(shift_counter))'(8);
            end else if (sck_pulse) begin
                shift_counter <= shift_counter - ($size(shift_counter))'(1);
            end
        end : shift_counter_proc
        
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // CS_N
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : cs_n_proc
            if (!reset_n) begin
                cs_n <= 1'b1;
            end else if (sync_reset | ctl_cs_high) begin
                cs_n <= 1'b1;
            end else if (ctl_cs_low) begin
                cs_n <= 0;
            end
        end : cs_n_proc
        
        assign mem_cs_n = cs_n;
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // SCK
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : sck_enable_proc
            if (!reset_n) begin
                sck_enable <= 0;
            end else if (sync_reset | ctl_sck_off) begin
                sck_enable <= 0;
            end else if (ctl_sck_on) begin
                sck_enable <= 1'b1;
            end
        end : sck_enable_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : sck_counter_proc
            if (!reset_n) begin
                sck_counter <= 0;
            end else if (sync_reset | (~sck_enable)) begin
                sck_counter <= 0;
            end else if (sck_enable) begin
                if (sck_counter == (CLK_SCK_RATIO - 1)) begin
                    sck_counter <= 0;
                end else begin
                    sck_counter <= sck_counter + ($size(sck_counter))'(1);
                end
            end 
        end : sck_counter_proc
            
        always_ff @(posedge clk, negedge reset_n) begin : sck_out_proc
            if (!reset_n) begin
                mem_sck <= 0;
            end else if ((sck_counter > (CLK_SCK_RATIO_DIV_2 - 1)) && sck_enable) begin
                mem_sck <= 1'b1;
            end else begin
                mem_sck <= 0;
            end
        end : sck_out_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : sck_pulse_proc
            if (!reset_n) begin
                sck_pulse <= 0;
            end else if (sck_counter == (CLK_SCK_RATIO - 2)) begin
                sck_pulse <= 1'b1;
            end else begin
                sck_pulse <= 0;
            end
        end : sck_pulse_proc
                
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // mem_mode
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : mem_mode_proc
            if (!reset_n) begin
                mem_mode <= M23XX1024_SEQ_MODE;
            end else if (ctl_load_mem_mode) begin
                mem_mode <= write_data_reg [7 : 6];
            end
        end : mem_mode_proc
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // FSM
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                
        enum {S_IDLE, S_INSTRUCTION, S_INST_SHIFT, S_NEXT_STAGE_AFTER_INST,
              S_ADDRESS_2, S_ADDRESS_1, S_ADDRESS_0, S_NEXT_STAGE_AFTER_ADDR,
              S_WRITE, S_READ} states = S_IDLE;
                
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
            
            ctl_cs_low = 0;
            ctl_cs_high = 0;
            
            ctl_sck_on = 0;
            ctl_sck_off = 0;
            
            ctl_shift_counter_load = 0;
            
            ctl_shift_inst_reg = 0;
            ctl_shift_addr_reg = 0;
            ctl_shift_write_data_reg = 0;
            
            ctl_reset_stage_register = 0;
            
            ctl_has_address_stage = 0;
            ctl_has_data_write_stage = 0;
            ctl_has_data_read_stage = 0;
            
            ctl_load_mem_mode = 0;
            
            ctl_write_data_grasp = 0;
            
            ctl_shift_read_data = 0;
            
            ctl_read_data_enable_out = 0;
            
            
            case (1'b1) // synthesis parallel_case 
                
                current_state[S_IDLE]: begin
                    ctl_cs_high = 1'b1;
                    ctl_sck_off = 1'b1;
                    ctl_reset_stage_register = 1'b1;
                    
                    if (instruction_start) begin
                        next_state [S_INSTRUCTION] = 1'b1;
                    end else begin
                        next_state [S_IDLE] = 1'b1;
                    end
                end
                
                current_state[S_INSTRUCTION]: begin
                    ctl_cs_low = 1'b1;
                    ctl_sck_on = 1'b1;
                    
                    ctl_shift_counter_load = 1'b1;
                    
                    case (instruction_reg)
                        M23XX1024_CMD_WRMR: begin
                            ctl_has_data_write_stage = 1'b1;
                            ctl_load_mem_mode = 1'b1;
                        end
                        
                        M23XX1024_CMD_RDMR: begin
                        end
                        
                        M23XX1024_CMD_WRITE: begin
                            ctl_has_data_write_stage = 1'b1;
                            ctl_has_address_stage = 1'b1;
                        end
                        
                        M23XX1024_CMD_READ: begin
                            ctl_has_data_read_stage = 1'b1;
                            ctl_has_address_stage = 1'b1;
                        end
                                                
                        default : begin
                            
                        end
                            
                    endcase
                    
                    next_state [S_INST_SHIFT] = 1'b1;
                            
                end
                
                current_state [S_INST_SHIFT]: begin
                    ctl_shift_inst_reg = 1'b1;
                    
                    if (sck_pulse && (shift_counter == 1)) begin
                        next_state [S_NEXT_STAGE_AFTER_INST] = 1'b1;
                    end else begin
                        next_state [S_INST_SHIFT] = 1'b1;
                    end
                end
                        
                current_state [S_NEXT_STAGE_AFTER_INST] : begin
                    ctl_shift_counter_load = 1'b1;
                    
                    if (has_address_stage) begin
                        next_state [S_ADDRESS_2] = 1'b1;
                    end else begin
                        next_state [S_NEXT_STAGE_AFTER_ADDR] = 1'b1;
                    end
                end
                
                current_state [S_ADDRESS_2] : begin
                    ctl_shift_addr_reg = 1'b1;
                    
                    if (sck_pulse && (shift_counter == 1)) begin
                        next_state [S_ADDRESS_1] = 1'b1;
                        ctl_shift_counter_load = 1'b1;
                    end else begin
                        next_state [S_ADDRESS_2] = 1'b1;
                    end
                end
                
                current_state [S_ADDRESS_1] : begin
                    ctl_shift_addr_reg = 1'b1;
                    
                    if (sck_pulse && (shift_counter == 1)) begin
                        next_state [S_ADDRESS_0] = 1'b1;
                        ctl_shift_counter_load = 1'b1;
                    end else begin
                        next_state [S_ADDRESS_1] = 1'b1;
                    end
                end
                
                current_state [S_ADDRESS_0] : begin
                    ctl_shift_addr_reg = 1'b1;
                    
                    if (sck_pulse && (shift_counter == 1)) begin
                        next_state [S_NEXT_STAGE_AFTER_ADDR] = 1'b1;
                    end else begin
                        next_state [S_ADDRESS_0] = 1'b1;
                    end
                end
                
                current_state [S_NEXT_STAGE_AFTER_ADDR] : begin
                    ctl_shift_counter_load = 1'b1;
                    
                    if (has_data_write_stage) begin
                        next_state [S_WRITE] = 1'b1;
                    end else if (has_data_read_stage) begin
                        next_state [S_READ] = 1'b1;
                    end else begin
                        ctl_cs_high = 1'b1;
                        ctl_sck_off = 1'b1;
                        next_state [S_IDLE] = 1'b1;
                    end
                end
                
                current_state [S_WRITE] : begin
                    ctl_shift_write_data_reg = 1'b1;
                    
                    if (sck_pulse && (shift_counter == 1)) begin
                        if ((mem_mode == M23XX1024_BYTE_MODE) || (!has_address_stage)) begin
                            ctl_cs_high = 1'b1;
                            ctl_sck_off = 1'b1;
                            next_state [S_IDLE] = 1'b1;
                        end else begin
                            ctl_shift_counter_load = 1'b1;
                            ctl_write_data_grasp = 1'b1;
                            next_state [S_WRITE] = 1'b1;
                        end
                    end else begin
                        next_state [S_WRITE] = 1'b1;
                    end
                end
                
                current_state [S_READ] : begin
                    ctl_shift_read_data = 1'b1; 

                    if (sck_pulse && (shift_counter == 1)) begin
                        ctl_read_data_enable_out = 1'b1;
                        
                        if ((mem_mode == M23XX1024_BYTE_MODE) || (!has_address_stage)) begin
                            ctl_cs_high = 1'b1;
                            ctl_sck_off = 1'b1;
                            next_state [S_IDLE] = 1'b1;
                        end else begin
                            ctl_shift_counter_load = 1'b1;
                            
                            next_state [S_READ] = 1'b1;
                        end
                    end else begin
                        next_state [S_READ] = 1'b1;
                    end
                end
                
                default: begin
                    next_state[S_IDLE] = 1'b1;
                end
                
            endcase
              
        end : state_machine_comb    


endmodule : M23XX1024

`default_nettype wire
