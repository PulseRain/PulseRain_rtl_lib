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
//   Serial port for 8051
//=============================================================================


`include "Serial_8051.svh"

`default_nettype none

module Serial_8051 #(parameter STABLE_TIME, MAX_BAUD_PERIOD) (
    
    //=======================================================================
    // clock / reset
    //=======================================================================
        
    input   wire                                clk,
    input   wire                                reset_n,
    
    //=======================================================================
    // host interface
    //=======================================================================
    
    input   wire                                start_TX,
    input   wire                                start_RX,
    
    input   wire                                class_8051_unit_pulse,
    input   wire                                timer_trigger,
    input   wire unsigned [7 : 0]               SBUF_in,
    input   wire unsigned [2 : 0]               SM,
    input   wire                                REN,
    output  logic unsigned [7 : 0]              SBUF_out,
    
    output  logic                               TI, // TX interrupt
    output  logic                               RI, // RX interrupt
    
    //=======================================================================
    // device interface
    //=======================================================================
    
    input   wire                                RXD,
    output  wire                                TXD
    
    
);

    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Signals
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        logic                                                               sync_reset;
        logic unsigned [2 : 0]                                              SM_d1;
        logic unsigned [2 : 0]                                              rxd_sr;
        logic unsigned [$clog2(STABLE_TIME + 1) - 1 : 0]                    stable_counter;
        logic                                                               baud_rate_pulse;
        logic unsigned [$clog2(MAX_BAUD_PERIOD) - 1 : 0]                    counter, counter_save;
        logic                                                               ctl_reset_stable_counter;
        logic                                                               ctl_save_counter;
        logic unsigned [$clog2 (SERIAL_8051_DEFAULT_DATA_LEN + 4) - 1 : 0]  data_counter;
        logic                                                               ctl_reset_data_counter;
        logic                                                               ctl_inc_data_counter;
        logic unsigned [10 : 0]                                             tx_data;                            
        logic                                                               ctl_load_tx_data;
        logic                                                               ctl_shift_tx_data;
        logic                                                               ctl_set_TI;
        logic                                                               ctl_set_RI;
        logic                                                               ctl_shift_rx_data;
        logic                                                               ctl_counter_reset;
        logic                                                               tx_start_flag;
        logic                                                               ctl_set_tx_start_flag;
        logic                                                               ctl_clear_tx_start_flag;
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // sync reset
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : sync_reset_proc
            if (!reset_n) begin
                SM_d1 <= 0;
                sync_reset <= 0;
            end else begin
                SM_d1 <= SM;
                if (SM_d1 != SM) begin
                    sync_reset <= 1'b1;
                end else begin
                    sync_reset <= 0;
                end
            end
        end : sync_reset_proc
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // TI / RI
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : TI_proc
            if (!reset_n) begin
                TI <= 0;
            end else if (ctl_set_TI) begin
                TI <= 1'b1;
            end else if (start_TX) begin
                TI <= 0;
            end
        end : TI_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : RI_proc
            if (!reset_n) begin
                RI <= 0;
            end else if (ctl_set_RI) begin
                RI <= 1'b1;
            end else if (start_RX) begin
                RI <= 0;    
            end
        end : RI_proc
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // baud_rate_pulse
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : baud_rate_pulse_proc
            if (!reset_n) begin
                baud_rate_pulse <= 0;
            end else if (sync_reset) begin
                baud_rate_pulse <= 0;
            end else if (SM [1 : 0] == SERIAL_8051_MODE_8_BIT_SR) begin
                baud_rate_pulse <= class_8051_unit_pulse;
            end else begin
                baud_rate_pulse <= timer_trigger;
            end
        end : baud_rate_pulse_proc
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // tx_data
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : tx_data_proc
            if (!reset_n) begin
                tx_data <= 0;
            end else if (ctl_load_tx_data) begin
                tx_data <= {1'b1, SBUF_in, 2'b01};
            end else if (ctl_shift_tx_data) begin
                tx_data <= {1'b1, tx_data [$high(tx_data) : 1]};
            end
        end : tx_data_proc

        assign TXD = tx_data [0];
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // rx_data
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : SBUF_out_proc
            if (!reset_n) begin
                SBUF_out <= 0;
            end else if (ctl_shift_rx_data) begin
                SBUF_out <= {rxd_sr[2], SBUF_out [$high(SBUF_out) : 1]};
            end
        end : SBUF_out_proc
        
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // rxd_sr
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : rxd_sr_proc
            if (!reset_n) begin
                rxd_sr <= 0;
            end else  begin
                rxd_sr <= {rxd_sr [$high(rxd_sr) - 1 : 0] , RXD};
            end
        end : rxd_sr_proc
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // counter
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : counter_proc
            if (!reset_n) begin
                counter <= 0;
            end else if (sync_reset | ctl_counter_reset) begin
                counter <= 0;
            end else if (baud_rate_pulse) begin
                counter <= 0;
            end else begin
                counter <= counter + ($size(counter))'(1);
            end
        end : counter_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : counter_save_proc
            if (!reset_n) begin
                counter_save <= 0;
            end else if (sync_reset | ctl_counter_reset) begin
                counter_save <= 0;
            end else if (ctl_save_counter) begin
                counter_save <= counter;
            end         
        end : counter_save_proc
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // data_counter
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : data_counter_proc
            if (!reset_n) begin
                data_counter <= 0;
            end else if (ctl_reset_data_counter) begin
                data_counter <= 0;
            end else if (ctl_inc_data_counter) begin
                data_counter <= data_counter + ($size(data_counter))'(1);
            end
        end : data_counter_proc
        
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // stable_counter
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : stable_counter_proc
            if (!reset_n) begin
                stable_counter <= 0;
            end else if (ctl_reset_stable_counter) begin
                stable_counter <= 0;
            end else begin
                stable_counter <= stable_counter + ($size(stable_counter))'(1);
            end         
        end : stable_counter_proc
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // tx_start_flag
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : tx_start_flag_proc
            if (!reset_n) begin
                tx_start_flag <= 0;
            end else if (ctl_clear_tx_start_flag) begin
                tx_start_flag <= 0;
            end else if (ctl_set_tx_start_flag) begin
                tx_start_flag <= 1'b1;
            end
        end : tx_start_flag_proc
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // FSM
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                
        enum {S_IDLE, S_RX_START, S_TX_START, S_RX_START_BIT, S_RX_DATA, 
              S_TX_DATA, S_RX_STOP_BIT, S_TX_WAIT, S_TX_WAIT2} states = S_IDLE;
                
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
            
            ctl_reset_stable_counter = 0;
            ctl_save_counter = 0;
            ctl_reset_data_counter = 0;
            
            ctl_inc_data_counter = 0;
            
            ctl_load_tx_data = 0;
            
            ctl_shift_tx_data = 0;
            ctl_shift_rx_data = 0;
                        
            ctl_set_TI = 0;
            ctl_set_RI = 0;
            ctl_counter_reset = 0;
            
            ctl_set_tx_start_flag = 0;
            ctl_clear_tx_start_flag = 0;
            
            case (1'b1) // synthesis parallel_case 
                
                current_state[S_IDLE]: begin
                    ctl_load_tx_data = 1'b1;
                    ctl_reset_data_counter = 1'b1;
                    ctl_counter_reset = 1'b1;
                    
                    ctl_clear_tx_start_flag = 1'b1;
                    
                    if (REN) begin
                        if (start_RX) begin
                            next_state [S_RX_START] = 1'b1;
                        end else begin
                            next_state [S_IDLE] = 1'b1;
                        end
                    end else if (start_TX) begin
                        next_state [S_TX_START] = 1'b1;
                    end else begin
                        next_state [S_IDLE] = 1'b1;
                    end
                end
                
                current_state [S_TX_START] : begin
                    ctl_reset_data_counter = 1'b1;
                    
                    if (REN) begin
                        next_state [S_RX_START] = 1'b1;
                    end else if (baud_rate_pulse) begin
                        if (tx_start_flag) begin
                            ctl_shift_tx_data = 1'b1;
                            next_state [S_TX_DATA] = 1'b1;
                        end else begin
                            ctl_set_tx_start_flag = 1'b1;
                            ctl_load_tx_data = 1'b1;
                            next_state [S_TX_START] = 1'b1;
                        end
                    end else begin
                        ctl_load_tx_data = 1'b1;
                        next_state [S_TX_START] = 1'b1;
                    end
                end
                
                current_state [S_TX_DATA] : begin
                    if (data_counter == (SERIAL_8051_DEFAULT_DATA_LEN + 3)) begin
                        ctl_set_TI = 1'b1;
                        next_state [S_IDLE] = 1;
                        //ctl_load_tx_data = 1'b1;
                        //next_state [S_TX_WAIT] = 1;
                    end else if (baud_rate_pulse) begin
                        ctl_shift_tx_data = 1'b1;
                        ctl_inc_data_counter = 1'b1;
                        next_state [S_TX_DATA] = 1;
                    end else begin
                        next_state [S_TX_DATA] = 1;
                    end
                end
                
                current_state [S_TX_WAIT] : begin
                    
                    ctl_load_tx_data = 1'b1;
                    if (baud_rate_pulse) begin
                        next_state [S_TX_WAIT2] = 1;
                    end else begin
                        next_state [S_TX_WAIT] = 1;
                    end
                end
                
                current_state [S_TX_WAIT2] : begin
                    
                    if (baud_rate_pulse) begin
                        ctl_set_TI = 1'b1;
                        next_state [S_IDLE] = 1;
                    end else begin
                        ctl_load_tx_data = 1'b1;                        
                        next_state [S_TX_WAIT2] = 1;
                    end
                end
                
                
                current_state [S_RX_START] : begin
                    ctl_reset_stable_counter = 1'b1;
                    ctl_clear_tx_start_flag = 1'b1;
                    
                    if (!REN) begin
                        next_state [S_TX_START] = 1'b1;
                    end else if (rxd_sr[2] & (~rxd_sr[1])) begin
                        next_state [S_RX_START_BIT] = 1'b1;
                    end else begin
                        next_state [S_RX_START] = 1'b1;
                    end
                    
                end
                
                current_state [S_RX_START_BIT] : begin
                
                    if (!rxd_sr[2]) begin
                        if (stable_counter == STABLE_TIME) begin
                            ctl_save_counter = 1'b1;
                            ctl_reset_data_counter = 0;
                            next_state [S_RX_DATA] = 1;
                        end else begin
                            next_state [S_RX_START_BIT] = 1;
                        end
                    end else begin
                        next_state [S_RX_START] = 1'b1;
                    end
                    
                end
                                
                current_state [S_RX_DATA] : begin
                    
                    if (counter == counter_save) begin
                        ctl_inc_data_counter = 1'b1;
                        ctl_shift_rx_data = 1'b1;
                    end 
                    
                    if (data_counter == SERIAL_8051_DEFAULT_DATA_LEN) begin
                        next_state [S_RX_STOP_BIT] = 1'b1;
                    end else begin
                        next_state [S_RX_DATA] = 1;
                    end
                    
                end
                
                current_state [S_RX_STOP_BIT] : begin
                    if (counter == counter_save) begin
                        ctl_set_RI = 1'b1;
                        next_state [S_IDLE] = 1;
                    end else begin
                        next_state [S_RX_STOP_BIT] = 1;
                    end
                end
                
                default: begin
                    next_state[S_IDLE] = 1'b1;
                end
                
            endcase
              
        end : state_machine_comb    

endmodule : Serial_8051

`default_nettype wire
