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

`include "I2C.svh"

`default_nettype none

module I2C_Slave ( // For 96MHz clock, 96Mhz / 960 = 100KHz
        input  wire                             clk,
        input  wire                             reset_n,
        input  wire                             sync_reset,
        
        input  wire                             start,
        input  wire                             stop,
        
        input  wire [I2C_DATA_LEN - 1 : 0]      outbound_data,
        
        input  wire                             addr_or_data_load,
        output logic                            data_request,
        
        
        output logic                            i2c_addr_match,    
        output logic                            data_ready,
        
        output logic unsigned [I2C_DATA_LEN - 1 : 0]    incoming_data_reg,
        
        output logic                            no_ack_flag,
               
        input  wire                             sda_in,
        input  wire                             scl_in,
        output logic                            sda_out,
        output logic                            scl_out
        
);
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Signals
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        logic unsigned [$clog2(I2C_DATA_LEN) - 1 : 0]   sda_counter;
        
        logic unsigned [I2C_SLAVE_ADDR_LENGTH - 1 : 0]  slave_addr;
        
        logic unsigned [3 : 0]                          sda_in_sr;
        logic unsigned [3 : 0]                          scl_in_sr;
        
        logic unsigned [I2C_DATA_LEN - 1 : 0]           outbound_data_reg;
        
        logic                                           sda_rising_pulse;
        logic                                           sda_falling_pulse;
        
        logic                                           start_condition_detect;
        logic                                           stop_condition_detect;
            
            
        logic                                           scl_rising_pulse;
        logic                                           scl_falling_pulse;
        
        logic                                           r1w0_reg;
        logic                                           ctl_load_incoming_data;
        logic                                           ctl_load_sda_counter;
        logic                                           ctl_dec_sda_counter;
        logic                                           ctl_set_scl_high;
        logic                                           ctl_set_scl_low;
        logic                                           ctl_set_sda_low;
        logic                                           ctl_set_sda_high; 
            
        
        logic                                           ctl_clear_data_ready;
        logic                                           ctl_set_data_ready;
        
        logic                                           ctl_set_i2c_addr_match;
        logic                                           ctl_clear_i2c_addr_match; 
        
        logic                                           ctl_load_r1w0_reg;
        
        logic                                           ctl_set_data_request;
        logic                                           ctl_clear_data_request;
        logic                                           ctl_load_read_data;
        
        logic                                           ctl_set_no_ack_flag;
        logic                                           ctl_clear_no_ack_flag;
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // slave address 
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : slave_addr_proc
            if (!reset_n) begin
                slave_addr <= 0;
            end else if (start) begin
                slave_addr <= outbound_data [I2C_SLAVE_ADDR_LENGTH - 1 : 0];
            end
        end : slave_addr_proc
        
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // data_ready
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : data_ready_proc
            if (!reset_n) begin
                data_ready <= 0;
            end else if (ctl_clear_data_ready | addr_or_data_load) begin
                data_ready <= 0;
            end else if (ctl_set_data_ready) begin
                data_ready <= 1'b1;
            end
        end : data_ready_proc    
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // data_request
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : data_request_proc
            if (!reset_n) begin
                data_request <= 0;
            end else if (ctl_clear_data_request | addr_or_data_load) begin
                data_request <= 0;
            end else if (ctl_set_data_request) begin
                data_request <= 1'b1;
            end
        end : data_request_proc    
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // address match
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : i2c_addr_match_proc
            if (!reset_n) begin
                i2c_addr_match <= 0;
            end else if (ctl_set_i2c_addr_match) begin
                i2c_addr_match <= 1'b1;
            end else if (ctl_clear_i2c_addr_match | addr_or_data_load) begin
                i2c_addr_match <= 0;
            end
        end : i2c_addr_match_proc
          
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // SDA 
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : sda_proc 
            if (!reset_n) begin
                sda_out <= 0;
            end else begin
                
                case (1'b1) // synthesis parallel_case
                    
                    ctl_set_sda_high : begin
                        sda_out <= 1'b1;    
                    end
                    
                    ctl_set_sda_low : begin
                        sda_out <= 0;
                    end
                    
                    ctl_load_read_data : begin
                        sda_out <= outbound_data_reg [$high (outbound_data_reg)];
                    end
                    
                    default : begin
                        
                    end
                    
                endcase
                
            end
        end : sda_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : outbound_data_reg_proc
            if (!reset_n) begin
                outbound_data_reg <= 0;
            end else if (addr_or_data_load) begin
                outbound_data_reg <= outbound_data;
            end else if (ctl_load_read_data) begin
                outbound_data_reg <= {outbound_data_reg [$high(outbound_data_reg) - 1 : 0], 1'b1};
            end
        end : outbound_data_reg_proc
                        
       
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // SCL 
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
       
        always_ff @(posedge clk, negedge reset_n) begin : scl_out_proc
            if (!reset_n) begin
                scl_out <= 0;
            end else if (ctl_set_scl_high) begin
                scl_out <= 1'b1;
            end else if (ctl_set_scl_low) begin
                scl_out <= 0;
            end
        end : scl_out_proc
        
        
        always_ff @(posedge clk, negedge reset_n) begin : sda_in_sr_proc
            if (!reset_n) begin
                sda_in_sr <= 0;
                scl_in_sr <= 0;
            end else begin
                sda_in_sr <= {sda_in_sr[$high(sda_in_sr) - 1 : 0], sda_in};
                scl_in_sr <= {scl_in_sr[$high(scl_in_sr) - 1 : 0], scl_in};
            end
        end : sda_in_sr_proc
            
                
        always_ff @(posedge clk, negedge reset_n) begin : scl_pulse_proc
            if (!reset_n) begin
                sda_rising_pulse  <= 0;
                sda_falling_pulse <= 0;
        
                scl_rising_pulse  <= 0;
                scl_falling_pulse <= 0;
            end else begin
                sda_rising_pulse <= (~sda_in_sr[$high(sda_in_sr)]) & sda_in_sr[$high(sda_in_sr) - 1];
                sda_falling_pulse <= (sda_in_sr[$high(sda_in_sr)]) & (~sda_in_sr[$high(sda_in_sr) - 1]);
                
                scl_rising_pulse <= (~scl_in_sr[$high(scl_in_sr)]) & scl_in_sr[$high(scl_in_sr) - 1];
                scl_falling_pulse <= (scl_in_sr[$high(scl_in_sr)]) & (~scl_in_sr[$high(scl_in_sr) - 1]);
            end
        end : scl_pulse_proc
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // address / data register
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  
        always_ff @(posedge clk, negedge reset_n) begin : sda_counter_proc
            if (!reset_n) begin
                sda_counter <= 0;
            end else if (sync_reset | start) begin 
                sda_counter <= 0;
            end else if (ctl_load_sda_counter) begin
                sda_counter <= I2C_DATA_LEN - ($size(sda_counter))'(1);
            end else if (ctl_dec_sda_counter) begin
                sda_counter <= sda_counter - ($size(sda_counter))'(1);
            end
        end : sda_counter_proc
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // incoming_data_reg
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : data_read_reg_proc
            if (!reset_n) begin
                incoming_data_reg <= 0;
            end else if (ctl_load_incoming_data) begin
                incoming_data_reg <= {incoming_data_reg [$high(incoming_data_reg) - 1 : 0], sda_in_sr[$high(sda_in_sr)]};
            end
        end : data_read_reg_proc
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // r1w0_reg
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : r1w0_reg_proc
            if (!reset_n) begin
                r1w0_reg <= 0;
            end else if (ctl_load_r1w0_reg) begin
                r1w0_reg <= incoming_data_reg[0];
            end
        end : r1w0_reg_proc
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // start / stop condition
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : start_stop_proc
            if (!reset_n) begin
                start_condition_detect <= 0;    
                stop_condition_detect <= 0;
            end else begin
                start_condition_detect <= sda_falling_pulse & scl_in_sr[$high(scl_in_sr)];
                stop_condition_detect <= sda_rising_pulse & scl_in_sr[$high(scl_in_sr)];
            end
        end : start_stop_proc
         
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // no_ack_flag
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : no_ack_flag_proc
            if (!reset_n) begin
                no_ack_flag <= 0;
            end else if (ctl_set_no_ack_flag) begin
                no_ack_flag <= 1'b1;
            end else if (ctl_clear_no_ack_flag) begin
                no_ack_flag <= 0;
            end
        end : no_ack_flag_proc
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // FSM
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                
        enum {S_IDLE, S_START, S_ADDR, S_ADDR_ACK_NACK, S_NEXT, S_WRITE, S_WRITE_ACK_NACK,
              S_WRITE_CLK_STRETCH, S_READ_ACK_NACK, S_READ_ACK_NACK_EXT, S_READ, S_READ_CLK_STRETCH} states;
                    
        localparam FSM_NUM_OF_STATES = states.num();
        logic [FSM_NUM_OF_STATES - 1:0] current_state = 0, next_state;
        logic ctl_state_save;
                    
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
            
            ctl_load_sda_counter = 0;
            ctl_load_incoming_data = 0;
            ctl_dec_sda_counter = 0;
                
            ctl_set_scl_high = 0;
            ctl_set_scl_low = 0;
            
            ctl_clear_data_ready = 0;
            ctl_set_data_ready = 0;
            
            ctl_set_i2c_addr_match = 0;
            ctl_clear_i2c_addr_match = 0; 
            
            ctl_load_r1w0_reg = 0;
            
            ctl_set_sda_low = 0;
            ctl_set_sda_high = 0;
            
            ctl_set_data_request = 0;
            ctl_clear_data_request = 0;
        
            ctl_load_read_data = 0;
            
            ctl_set_no_ack_flag = 0;
            ctl_clear_no_ack_flag = 0;
            
            case (1'b1) // synthesis parallel_case 
                    
                current_state[S_IDLE]: begin
                    
                    ctl_set_scl_high = 1'b1;
                    ctl_set_sda_high = 1'b1;
                    ctl_clear_i2c_addr_match = 1'b1;
                    ctl_clear_data_ready = 1'b1;
                    ctl_clear_no_ack_flag = 1'b1;
                    
                    if (start) begin
                        next_state [S_START] = 1'b1;
                    end else begin
                        next_state [S_IDLE] = 1'b1;
                    end
                end
                
                current_state [S_START] : begin
                    ctl_load_sda_counter = 1'b1;
                    ctl_set_scl_high = 1'b1;
                    ctl_set_sda_high = 1'b1;
                    ctl_clear_i2c_addr_match = 1'b1;
                    ctl_clear_data_ready = 1'b1;
                    
                    if (sda_falling_pulse & scl_in_sr[$high(scl_in_sr)]) begin
                        next_state [S_ADDR] = 1'b1;   
                    end else begin
                        next_state [S_START] = 1'b1;    
                    end
                end
                
                current_state [S_ADDR] : begin
                    ctl_clear_no_ack_flag = 1'b1;
                    ctl_load_incoming_data = scl_rising_pulse;
                    
                    if (scl_rising_pulse) begin
                        ctl_dec_sda_counter = 1'b1;
                        
                        if (!sda_counter) begin
                            next_state [S_ADDR_ACK_NACK] = 1'b1;
                        end else begin
                            next_state [S_ADDR] = 1'b1;
                        end
                        
                    end else begin
                        next_state [S_ADDR] = 1'b1;
                    end
                        
                end
                
                current_state [S_ADDR_ACK_NACK] : begin
                    ctl_load_r1w0_reg = 1'b1;
                    
                    if (scl_falling_pulse) begin
                        if (slave_addr == incoming_data_reg [$high(incoming_data_reg) - 1 : 1]) begin
                           ctl_set_i2c_addr_match = 1'b1;
                           ctl_set_sda_low = 1'b1; // ack
                           next_state [S_NEXT] = 1'b1;
                        end else begin
                           // nack
                           next_state [S_START] = 1'b1;
                        end
                    end else begin
                        next_state [S_ADDR_ACK_NACK] = 1'b1;
                    end
                end
                
                
                current_state [S_NEXT] : begin
                    
                    ctl_load_sda_counter = 1'b1; 
                    ctl_set_sda_high = scl_falling_pulse;
                    
                    if (scl_falling_pulse) begin
                        if (!r1w0_reg) begin
                            next_state [S_WRITE] = 1'b1;
                        end else begin
                            ctl_set_scl_low = 1'b1;
                            ctl_set_data_request = 1'b1;
                            next_state [S_READ_CLK_STRETCH] = 1'b1;
                        end
                    end else begin
                        next_state [S_NEXT] = 1'b1;
                    end
                end
                
                current_state [S_WRITE] : begin
                    
                    if (start_condition_detect) begin
                        ctl_load_sda_counter = 1'b1;
                        ctl_set_scl_high = 1'b1;
                        ctl_set_sda_high = 1'b1;
                        ctl_clear_i2c_addr_match = 1'b1;
                        ctl_clear_data_ready = 1'b1;
                        
                        next_state [S_ADDR] = 1'b1;
                    end else if (scl_rising_pulse) begin
                        ctl_dec_sda_counter = 1'b1;
                        ctl_load_incoming_data = 1'b1;
                        
                        if (!sda_counter) begin
                            ctl_set_data_ready = 1'b1;
                            
                            next_state [S_WRITE_ACK_NACK] = 1'b1;
                        end else begin
                            next_state [S_WRITE] = 1'b1;
                        end
                        
                    end else begin
                        next_state [S_WRITE] = 1'b1;
                    end
                   
                end
                
                current_state [S_WRITE_ACK_NACK] : begin
                    
                    ctl_set_sda_low = scl_falling_pulse;
                    ctl_set_scl_low = scl_falling_pulse;
                    
                    if (scl_falling_pulse) begin
                        next_state [S_WRITE_CLK_STRETCH] = 1'b1;
                    end else begin
                        next_state [S_WRITE_ACK_NACK] = 1'b1;
                    end
                           
                end
                
                current_state [S_WRITE_CLK_STRETCH] : begin
                    if (data_ready) begin
                       next_state [S_WRITE_CLK_STRETCH] = 1'b1;        
                    end else begin
                       ctl_set_scl_high = 1'b1;
                       
                       if (scl_falling_pulse) begin
                           ctl_set_sda_high = 1'b1;
                           ctl_load_sda_counter = 1'b1; 
                           next_state [S_WRITE] = 1'b1;
                       end else begin
                           next_state [S_WRITE_CLK_STRETCH] = 1'b1;
                       end
                    end
                end
                
                
                current_state [S_READ_CLK_STRETCH] : begin
                    ctl_load_sda_counter = 1'b1; 
                    
                    if (data_request) begin
                        next_state [S_READ_CLK_STRETCH] = 1'b1;
                    end else begin
                        ctl_set_scl_high = 1'b1;
                        ctl_load_read_data = 1'b1;
                        next_state [S_READ] = 1'b1;
                    end
                end
                
                current_state [S_READ] : begin
                    ctl_load_read_data = scl_falling_pulse;
                    ctl_dec_sda_counter = scl_falling_pulse; 
                    
                    if ((scl_falling_pulse) && (!sda_counter)) begin
                        next_state [S_READ_ACK_NACK] = 1'b1;
                    end else begin    
                        next_state [S_READ] = 1'b1;
                    end
                end
                
                
                current_state [S_READ_ACK_NACK] : begin
                    
                    ctl_set_sda_high = 1'b1;
                    
                    if (scl_rising_pulse) begin
                        if (sda_in_sr[$high(sda_in_sr)]) begin
                            ctl_set_no_ack_flag = 1'b1; // no ack from master
                            next_state [S_START] = 1'b1;
                        end else begin
                            ctl_set_data_request = 1'b1;
                            next_state [S_READ_ACK_NACK_EXT] = 1'b1;
                        end
                    end else begin
                        next_state [S_READ_ACK_NACK] = 1'b1;
                    end
                end
                
                current_state [S_READ_ACK_NACK_EXT] : begin
                    ctl_set_scl_low = scl_falling_pulse;
                    
                    if (scl_falling_pulse) begin
                        next_state [S_READ_CLK_STRETCH] = 1'b1;
                    end else begin
                        next_state [S_READ_ACK_NACK_EXT] = 1'b1;
                    end
                end
                
                default: begin
                    next_state[S_IDLE] = 1'b1;
                end
                    
            endcase
                  
        end : state_machine_comb
           
        

endmodule : I2C_Slave
       
    
`default_nettype wire
