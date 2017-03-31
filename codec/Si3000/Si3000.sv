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
//    Core module for Silicon Labs, Si3000 voice codec
//    Digital Interface mode 0 is used. And do the following at top level
//
//     assign Si3000_SCLK = (Si3000_RESET_N) ? 1'bZ : 1'b0;
//     assign Si3000_SDO = (Si3000_FSYNC_N) ? 1'b0 : 1'bZ;
//
// References:
//   [1] Si3000, VoiceBand CODEC with Microphone/Speaker Drive, Rev 1.4,
//       Silicon Labs, 12/2010
//=============================================================================

`include "Si3000.svh"

`default_nettype none

module Si3000 #(parameter MCLK_DENOM = 1, MCLK_NUMER = 24, WORD_SIZE = 16) (

    //=======================================================================
    // clock / reset
    //=======================================================================
    

    input   wire                                clk,
    input   wire                                reset_n,
    
    input   wire                                sync_reset,
    input   wire                                mclk_enable,

    
    //=======================================================================
    // host interface
    //=======================================================================
    
    input   wire unsigned [15 : 0]              write_data,
    
    output  logic                               write_data_grasp,
    output  logic unsigned [15 : 0]             read_data,
    output  logic                               done,
    
    
    //=======================================================================
    // device interface
    //=======================================================================
    
    input   wire                                Si3000_SDO,
    output  wire                                Si3000_SDI,

    input   wire                                Si3000_SCLK,
    input   wire                                Si3000_FSYNC_N,
    
    output  wire                                Si3000_MCLK,
    output  wire                                fsync_out

);
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Signals
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        logic                                           codec_enable_d1;
        logic                                           mclk_enable_d1;
        logic unsigned [$clog2(MCLK_NUMER) : 0]         mclk_counter;
        logic                                           mclk_pulse;
        logic                                           mclk = 1'b1;
        logic unsigned [2 : 0]                          mclk_sr = 3'b111;
        
        logic                                           sclk_pulse;
            
        logic unsigned [15 : 0]                         data_write_reg;
    
        wire                                            cs_n;

        logic                                           ctl_done;
        wire                                            sclk;
    
        wire                                            data_in;

        logic unsigned [$clog2(WORD_SIZE) : 0]          data_shift_counter;
                
        logic unsigned [2 : 0]                          Si3000_SDO_sr;
        
        logic unsigned [2 : 0]                          fsync_sr;
        logic unsigned [2 : 0]                          sclk_sr;
        
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Si3000 Signals
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        assign Si3000_MCLK = mclk;
        assign Si3000_SDI = data_write_reg[$high(data_write_reg)]; 
        assign data_in = Si3000_SDO_sr[$high(Si3000_SDO_sr)];
        assign cs_n = Si3000_FSYNC_N;
        assign sclk = Si3000_SCLK;
        
        always_ff @(posedge clk, negedge reset_n) begin : Si3000_SDO_sr_proc
            if (!reset_n) begin
                Si3000_SDO_sr <= 0;
            end else begin
                Si3000_SDO_sr <= {Si3000_SDO_sr[$high(Si3000_SDO_sr) - 1 : 0], Si3000_SDO};
            end
            
        end : Si3000_SDO_sr_proc
                
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // MCLK
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : mclk_enable_d1_proc
            if (!reset_n) begin
                mclk_enable_d1 <= 0;
            end else begin
                mclk_enable_d1 <= mclk_enable;
            end
        end : mclk_enable_d1_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : mclk_counter_proc
            if (!reset_n) begin
                mclk_counter <= 0;
                mclk_pulse   <= 0;
            end else if ((~mclk_enable_d1) & mclk_enable) begin
                mclk_counter <= 0;
                mclk_pulse   <= 0;
            end else if (mclk_enable) begin
                if (mclk_counter < (MCLK_NUMER - MCLK_DENOM)) begin
                    mclk_counter <= mclk_counter + ($size(mclk_counter))'(MCLK_DENOM);
                    mclk_pulse <= 0;
                end else begin
                    mclk_counter <= mclk_counter - ($size(mclk_counter))'(MCLK_NUMER - MCLK_DENOM);
                    mclk_pulse <= 1'b1;
                end
            end else begin
                mclk_pulse <= 0;
            end
        end : mclk_counter_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : mclk_proc
            if (!reset_n) begin
                mclk <= 1'b1;
            end else if (mclk_enable) begin
                if (mclk_pulse) begin
                    mclk <= 0;
                end else if (mclk_counter > (MCLK_NUMER / 2)) begin
                    mclk <= 1'b1;
                end
            end else begin
                mclk <= 1'b1;
            end
        end : mclk_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : mclk_sr_proc
            if (!reset_n) begin
                mclk_sr <= 3'b111;
            end else begin
                mclk_sr <= {mclk_sr[$high(mclk_sr) - 1: 0], mclk}; 
            end
        end : mclk_sr_proc
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // SCLK
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : sr_proc
            if (!reset_n) begin
                fsync_sr <= 0;
                sclk_sr <= 0;
                sclk_pulse <= 0;
            end else begin
                fsync_sr <= {fsync_sr[$high(fsync_sr) - 1 : 0], cs_n};
                sclk_sr <= {sclk_sr[$high(sclk_sr) - 1 : 0], sclk};
                sclk_pulse <= sclk_sr[$high(sclk_sr)] & (~sclk_sr[$high(sclk_sr) - 1]);
            end
        end : sr_proc
    
        assign fsync_out = fsync_sr[$high(fsync_sr)] & (~fsync_sr[$high(fsync_sr) - 1]);
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    //  done
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : done_proc
            if (!reset_n) begin
                done <= 0;
            end else if (fsync_out) begin
                done <= 0;
            end else if (ctl_done) begin
                done <= 1'b1;
            end
        end : done_proc
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // read data
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
            
        always_ff @(posedge clk, negedge reset_n) begin : read_data_proc
            if (!reset_n) begin
                read_data <= 0;
            end else if (fsync_out) begin
                read_data <= 0;
            end else if (sclk_pulse & (~fsync_sr[$high(fsync_sr)])) begin
                read_data <= {read_data [$high(read_data)  - 1 : 0], data_in};
            end
        end : read_data_proc
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // write_data_grasp
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : write_data_grasp_proc
            if (!reset_n) begin
                write_data_grasp <= 0;
            end else if (fsync_out) begin
                write_data_grasp <= 1'b1;
            end else begin
                write_data_grasp <= 0;
            end
        end : write_data_grasp_proc
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // data_write_reg
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : data_write_reg_proc
            if (!reset_n) begin
                data_write_reg <= 0;
                data_shift_counter <= 0;
            end else if (fsync_out) begin
                data_write_reg <= write_data;
                data_shift_counter <= 0;
            end else if (sclk_pulse & (~fsync_sr[$high(fsync_sr)])) begin
                data_write_reg <= 
                    {data_write_reg [$high(data_write_reg) - 1 : 0], data_write_reg[$high(data_write_reg)]};
                
                data_shift_counter <= data_shift_counter + ($size(data_shift_counter))'(1);
            end
        end : data_write_reg_proc

    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // FSM
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                
        enum {S_IDLE, S_DATA_RW, S_END} states = 0;
                
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

            ctl_done = 0;
            
            case (1'b1) // synthesis parallel_case 
                
                current_state[S_IDLE]: begin
                    if (fsync_out) begin
                        next_state [S_DATA_RW] = 1'b1;
                    end else begin
                        next_state [S_IDLE] = 1'b1;
                    end
                end
                
                                
                current_state [S_DATA_RW] : begin
                    
                    if (data_shift_counter != WORD_SIZE) begin
                        next_state [S_DATA_RW] = 1'b1;
                    end else begin
                        next_state [S_END] = 1'b1;
                    end
                end
                
                current_state [S_END]: begin
                    ctl_done = 1'b1;
                    next_state [S_IDLE] = 1'b1;
                    
                end
                
                default: begin
                    next_state[S_IDLE] = 1'b1;
                end
                
            endcase
              
        end : state_machine_comb    


endmodule : Si3000

`default_nettype wire
