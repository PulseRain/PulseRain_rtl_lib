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
//   SD Card in SPI mode. It will use a 1KB size buffer for ping /pong buffer.
// (Each sector size is 512 bytes). The buffer can be inferred, or can be 
// implemented by Megafunction (IP)
//=============================================================================

`include "SD_SPI.svh"
`include "CRC.svh"

`default_nettype none

module SD_true_dual_port_ram_single_clock
        (
        input wire [7:0] data_a, data_b,
        input wire [9:0] addr_a, addr_b,
        input wire we_a, we_b, clk,
        output reg [7:0] q_a, q_b
        );
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 6;
    // Declare the RAM variable
    reg [7:0] ram[1024-1:0];
    always @ (posedge clk)
    begin // Port A
        if (we_a)
        begin
            ram[addr_a] <= data_a;
            q_a <= data_a;
        end
        else
            q_a <= ram[addr_a];
    end
    always @ (posedge clk)
    begin // Port b
        if (we_b)
        begin
            ram[addr_b] <= data_b;
            q_b <= data_b;
        end
        else
            q_b <= ram[addr_b];
    end
endmodule

module SD_SPI #(parameter SD_CLK_SLOW_SCK_RATIO = 480, SD_CLK_FAST_SCK_RATIO = 12, 
                          BUFFER_SIZE_IN_BYTES = 1024) (
                          
    //=======================================================================
    // clock / reset
    //=======================================================================
                          
    input wire                                  clk,
    input wire                                  reset_n,
    
    input wire                                  sync_reset,

    
    //=======================================================================
    // command / response
    //=======================================================================
    
    input wire unsigned [1 : 0]                 response_type,
    input wire                                  sclk_slow0_fast1,
    
    input wire                                  start,
    input wire unsigned [5 : 0]                 cmd,
    input wire unsigned [31 : 0]                arg,
    
    //=======================================================================
    // ping / pong buffer 
    //=======================================================================
    
    input wire unsigned [$clog2(BUFFER_SIZE_IN_BYTES) - 1 : 0]  addr_base,
    
    input wire                                                  mem_wr,
    input wire unsigned [$clog2(BUFFER_SIZE_IN_BYTES) - 1 : 0]  mem_addr,
    input wire unsigned [7 : 0]                                 data_in,
    
    
    output wire                                                 data_en_out,
    output logic unsigned [7 : 0]                               data_out,
    
    
    //=======================================================================
    // SD card SPI interface 
    //=======================================================================
    
    output logic                                cs_n = 1'b1,
    output logic                                spi_clk,
    input  wire                                 sd_data_out,
    output logic                                sd_data_in,
    
    //=======================================================================
    // return / done 
    //=======================================================================
    
    output logic                                done,
    output logic unsigned [1 : 0]               ret_status
    
);
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Signals
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        logic                                           cs_n_i = 1'b1;
        logic                                           ctl_cs_low;
        logic                                           ctl_cs_high;
        logic unsigned [$clog2(SD_CLK_SLOW_SCK_RATIO) - 1 : 0]  sck_counter;
        logic unsigned [$clog2(SD_CLK_SLOW_SCK_RATIO) - 1 : 0]  sck_wrap_limit   = ($size(sck_wrap_limit))'(SD_CLK_SLOW_SCK_RATIO - 1);   
        logic unsigned [$clog2(SD_CLK_SLOW_SCK_RATIO) - 1 : 0]  sck_middle_point = ($size(sck_middle_point))'(SD_CLK_SLOW_SCK_RATIO / 2 - 1);   
            
        logic                                           sck_enable;
        logic                                           ctl_sck_on;
        logic                                           ctl_sck_off;
        logic unsigned [47 : 0]                         sd_data_in_reg = '1;
        logic unsigned [5 : 0]                          tx_counter;
        logic unsigned [6 : 0]                          crc;
        logic                                           sck_pulse;
        logic                                           spi_clk_d1;
        logic                                           spi_clk_d2;
        
        
        logic unsigned [2 : 0]                          response_bytes;
        logic unsigned [5 : 0]                          response_bits_received;
        
        logic                                           ctl_sd_data_shift;
        logic unsigned [7 : 0]                          data_receive_reg = '1;
        logic                                           ctl_data_shift_in;
        logic                                           ctl_clear_data_receive_reg;
        
        logic                                           ctl_mem_2nd_port_wr;
        logic                                           ctl_crc_input_en;
        logic unsigned [$clog2(BUFFER_SIZE_IN_BYTES) - 1 : 0]  mem_addr_2nd;
        logic unsigned [$clog2(BUFFER_SIZE_IN_BYTES) - 1 : 0]  tx_byte_counter;
        logic                                           ctl_clear_mem_addr_2nd;
        logic                                           ctl_inc_mem_addr_2nd;
        logic unsigned [7 : 0]                          data_out_2nd;
        
        logic                                           ctl_set_done;
        
        logic unsigned [7 : 0]                          time_out_counter;
        logic                                           ctl_load_time_out_counter;
        
        logic unsigned [9 : 0]                          data_length_in_bytes;   
        logic                                           ctl_load_data_length_16;
        logic                                           ctl_load_data_length_512;
        logic                                           ctl_dec_data_count;
        logic                                           ctl_clear_response_bits_received;
        
        logic unsigned [5 : 0]                          cmd_reg;
        logic                                           ctl_crc_sync_reset;
        wire  unsigned [15 : 0]                         crc_out;
        logic                                           ctl_set_ret_ok;
        logic                                           ctl_set_ret_crc_fail;
        logic                                           ctl_set_ret_time_out;
        logic                                           ctl_load_mem_to_reg;
        
        logic unsigned [7 : 0]                          data_out_2nd_reg;
        logic                                           ctl_init_data_out_2nd_reg;
        
        logic                                           ctl_load_tx_counter_for_byte;
        logic                                           ctl_load_tx_counter_for_two_byte;
                                                
        logic                                           ctl_load_crc_to_reg;
        logic                                           ctl_inc_tx_byte_counter;
            
              
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // CRC to send to SD Card
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_comb begin
            if (cmd == SD_CMD0) begin
                crc = 7'h4A;
            end else if (cmd == SD_CMD8) begin
                crc = 7'h43;
            end else begin
                crc = 7'h7F;
            end
        end
    
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // CRC (XModem)
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        crc16_CCITT #(.INIT_VALUE (16'h0)) crc16_CCITT_i (.*,
            .sync_reset (ctl_crc_sync_reset),
            .crc_en (ctl_crc_input_en),
            .data_in (data_receive_reg),
            .crc_out (crc_out)
        );  
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // sd_data_in_reg
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : sd_data_in_reg_proc
            if (!reset_n) begin
                sd_data_in_reg <= '1;
            end else begin
                
                case (1'b1) // synthesis parallel_case 
                    start : begin
                        sd_data_in_reg <= {2'b01, cmd, arg, crc, 1'b1};
                    end
                    
                    ctl_load_mem_to_reg : begin
                        sd_data_in_reg <= {data_out_2nd_reg, 40'hffff_ffff_ff};
                    end
                    
                    ctl_sd_data_shift : begin
                        sd_data_in_reg <= {sd_data_in_reg [$high(sd_data_in_reg) - 1 : 0], 1'b1};
                    end
                    
                    ctl_load_crc_to_reg : begin
                        sd_data_in_reg <= {crc_out, 32'hffff_ffff};
                    end
                    
                    default : begin
                        
                    end
                    
                endcase
            end
        end : sd_data_in_reg_proc

        always_ff @(posedge clk, negedge reset_n) begin : sd_data_in_proc
            if (!reset_n) begin
                sd_data_in <= 0;
            end else begin
                sd_data_in <= sd_data_in_reg[$high(sd_data_in_reg)] | cs_n;
            end
        end : sd_data_in_proc
        
        always_ff @(posedge clk) begin
            if (ctl_init_data_out_2nd_reg) begin
                data_out_2nd_reg <= 8'hfe;
            end else begin
                data_out_2nd_reg <= data_out_2nd;
            end
        end
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // CS_N
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        //==assign cs_n = cs_n_i;
        
        always_ff @(posedge clk, negedge reset_n) begin : cs_out_proc
            if (!reset_n) begin
                cs_n <= 1'b1;
            end else if (sck_pulse) begin
                cs_n <= cs_n_i;
            end
        end : cs_out_proc
        
        
        always_ff @(posedge clk, negedge reset_n) begin : cs_n_proc
            if (!reset_n) begin
                cs_n_i <= 1'b1;
            end else if (sync_reset | ctl_cs_high) begin
                cs_n_i <= 1'b1;
            end else if (ctl_cs_low) begin
                cs_n_i <= 0;
            end
        end : cs_n_proc
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // done
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : done_proc
            if (!reset_n) begin
                done <= 0;
            end else if (ctl_set_done) begin
                done <= 1'b1;
            end else begin
                done <= 0;
            end  
        end : done_proc
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Timeout Counter
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : time_out_counter_proc
            if (!reset_n) begin
                time_out_counter <= 0;
            end else if (ctl_load_time_out_counter) begin
                time_out_counter <= '1;
            end else if ((time_out_counter) && (~spi_clk_d2) && (spi_clk_d1)) begin
                time_out_counter <= time_out_counter - ($size(time_out_counter))'(1);
            end
        end : time_out_counter_proc
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // ret_status
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : ret_status_proc
            if (!reset_n) begin
                ret_status <= 0;
            end else begin
                case (1'b1) // synthesis parallel_case 
                    start : begin
                        ret_status <= 0;
                    end
                    
                    ctl_set_ret_ok : begin
                        ret_status <= SD_RET_OK;
                    end
                    
                    ctl_set_ret_crc_fail : begin
                        ret_status <= SD_RET_CRC_FAIL;
                    end
                    
                    ctl_set_ret_time_out : begin
                        ret_status <= SD_RET_TIME_OUT;
                    end
                    
                    default : begin
                        
                    end
                endcase
            end
        end : ret_status_proc
                    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // tx_byte_counter
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        always_ff @(posedge clk, negedge reset_n) begin : tx_byte_counter_proc
            if (!reset_n) begin
                tx_byte_counter <= 0;
            end else if (start) begin
                tx_byte_counter <= 0;
            end else if (ctl_inc_tx_byte_counter) begin
                tx_byte_counter <= tx_byte_counter + ($size(tx_byte_counter))'(1);
            end
        end : tx_byte_counter_proc
        
            
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // SPI clock
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
        
        always_ff @(posedge clk, negedge reset_n) begin : sck_wrap_limit_proc
            if (!reset_n) begin
                sck_wrap_limit   <= ($size(sck_wrap_limit))'(SD_CLK_SLOW_SCK_RATIO - 1);
                sck_middle_point <= ($size(sck_middle_point))'(SD_CLK_SLOW_SCK_RATIO / 2 - 1);
            end else if (sync_reset) begin
                sck_wrap_limit   <= sclk_slow0_fast1 ? ($size(sck_wrap_limit))'(SD_CLK_FAST_SCK_RATIO - 1) : ($size(sck_wrap_limit))'(SD_CLK_SLOW_SCK_RATIO - 1);
                sck_middle_point <= sclk_slow0_fast1 ? ($size(sck_middle_point))'(SD_CLK_FAST_SCK_RATIO / 2 - 1) : ($size(sck_middle_point))'(SD_CLK_SLOW_SCK_RATIO / 2 - 1);
            end
        end : sck_wrap_limit_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : sck_counter_proc
            if (!reset_n) begin
                sck_counter <= 0;
            end else if (sync_reset | (~sck_enable)) begin
                sck_counter <= 0;
            end else if (sck_enable) begin
                if (sck_counter == sck_wrap_limit) begin
                    sck_counter <= 0;
                end else begin
                    sck_counter <= sck_counter + ($size(sck_counter))'(1);
                end
            end 
        end : sck_counter_proc
            
        always_ff @(posedge clk, negedge reset_n) begin : sck_out_proc
            if (!reset_n) begin
                spi_clk <= 0;
            end else if ((sck_counter > sck_middle_point) && sck_enable) begin
                spi_clk <= 1'b1;
            end else begin
                spi_clk <= 0;
            end
        end : sck_out_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : sck_pulse_proc
            if (!reset_n) begin
                sck_pulse <= 0;
            end else if (sck_counter == (sck_wrap_limit - 1)) begin
                sck_pulse <= 1'b1;
            end else begin
                sck_pulse <= 0;
            end
        end : sck_pulse_proc
                
        
        always_ff @(posedge clk, negedge reset_n) begin : tx_counter_proc
            if (!reset_n) begin
                tx_counter <= 0;
            end else begin
                
                case (1'b1) // synthesis parallel_case 
                    
                    start : begin
                        tx_counter <= 48;
                    end
                    
                    ctl_load_tx_counter_for_two_byte : begin
                        tx_counter <= 16;
                    end
                    
                    ctl_load_tx_counter_for_byte : begin
                        tx_counter <= 8;
                    end
                    
                    sck_pulse : begin
                        tx_counter <= tx_counter - ($size(tx_counter))'(1);
                    end
						  
						  default : begin
						  
						  end
                    
                endcase
            end 
        end : tx_counter_proc
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // receive data / response
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        always_ff @(posedge clk, negedge reset_n) begin : response_bytes_proc
            if (!reset_n) begin
                response_bytes <= 0;
            end else if (start) begin
                case (response_type) // synthesis parallel_case 
                    SD_R2 : begin
                        response_bytes <= 2;
                    end
                    
                    SD_R3_R7 : begin
                        response_bytes <= 5;
                    end
                    
                    default : begin
                        response_bytes <= 1;
                    end
                    
                endcase
            end
        end : response_bytes_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : response_bits_received_proc
            if (!reset_n) begin
                response_bits_received <= 0;
            end else if (start | ctl_clear_response_bits_received) begin
                response_bits_received <= 0;
            end else if (ctl_data_shift_in) begin
                response_bits_received <= response_bits_received + ($size(response_bits_received))'(1);
            end
        end : response_bits_received_proc
        
            
        
        always_ff @(posedge clk, negedge reset_n) begin : data_receive_reg_proc
            if (!reset_n) begin
                data_receive_reg <= '1;
            end else if (ctl_clear_data_receive_reg) begin
                data_receive_reg <= '1;
            end else if (ctl_load_mem_to_reg) begin
                data_receive_reg <= data_out_2nd_reg;
            end else if (ctl_data_shift_in) begin
                data_receive_reg <= {data_receive_reg [$high (data_receive_reg) - 1 : 0], sd_data_out};
            end
        end : data_receive_reg_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : delay_proc
            if (!reset_n) begin
                spi_clk_d1 <= 0;
                spi_clk_d2 <= 0;
            end else begin
                spi_clk_d1 <= spi_clk;
                spi_clk_d2 <= spi_clk_d1;
            end
        end : delay_proc
            
    
        always_ff @(posedge clk, negedge reset_n) begin : data_length_in_bytes_proc
            if (!reset_n) begin
                data_length_in_bytes <= 0;
            end else if (ctl_load_data_length_512) begin
                data_length_in_bytes <= 512;
            end else if (ctl_load_data_length_16) begin
                data_length_in_bytes <= 16;
            end else if (ctl_dec_data_count) begin
                data_length_in_bytes <= data_length_in_bytes - ($size(data_length_in_bytes))'(1);
            end
        end : data_length_in_bytes_proc
            
        always_ff @(posedge clk, negedge reset_n) begin : cmd_reg_proc
            if (!reset_n) begin
                cmd_reg <= 0;
            end else if (start) begin
                cmd_reg <= cmd;
            end
        end : cmd_reg_proc
        
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // true dual port
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        SD_DP_RAM_BUF SD_DP_RAM_BUF_i (
                .address_a (mem_addr),
                .address_b (mem_addr_2nd),
                .clock (clk),
                .data_a (data_in),
                .data_b (data_receive_reg),
                .wren_a (mem_wr),
                .wren_b (ctl_mem_2nd_port_wr),
                .q_a (data_out),
                .q_b (data_out_2nd));


        /*
        SD_true_dual_port_ram_single_clock true_dual_port_ram_single_clock_i
        ( .data_a (data_in),
          .data_b (data_receive_reg),
          .addr_a (mem_addr), 
          .addr_b (mem_addr_2nd),
          .we_a (mem_wr), 
          .we_b (ctl_mem_2nd_port_wr), 
          .clk (clk),
          .q_a (data_out), 
          .q_b (data_out_2nd)
        );*/
        
        /*
        SD_DP_RAM_BUF #(.BUFFER_SIZE_IN_BYTES (BUFFER_SIZE_IN_BYTES))  SD_DP_RAM_BUF_i (.*,
            .mem_wr (mem_wr),
            .mem_addr (mem_addr),
            .data_in (data_in),
            .data_out (data_out),
            
            .mem_wr_2nd (ctl_mem_2nd_port_wr),
            .mem_addr_2nd (mem_addr_2nd),
            .data_receive (data_receive_reg),
            .data_out_2nd (data_out_2nd)    
        );
        */
        always_ff @(posedge clk) begin : mem_addr_2nd_proc
            if (ctl_clear_mem_addr_2nd) begin
                mem_addr_2nd <= addr_base;
            end else if (ctl_inc_mem_addr_2nd) begin
                mem_addr_2nd <= mem_addr_2nd + ($size(mem_addr_2nd))'(1);
            end
        end : mem_addr_2nd_proc
        
        assign data_en_out = 1'b1;
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // FSM
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                
        enum {S_IDLE, S_CS_LOW, S_CS_LOW_WAIT, S_DATA_TX_WAIT, S_DATA_TX, S_WAIT_RESPONSE, S_RECEIVE,
              S_READ_PREPARE, S_READ_WAIT, S_READ, S_CRC_HIGH, S_CRC_LOW, S_CRC_CHECK,
              S_WRITE_PREPARE, S_WRITE_WAIT, S_WRITE, S_WRITE_CHECK, S_SEND_CRC_WAIT, S_SEND_CRC,
              S_DATA_RESPONSE, S_DATA_RESPONSE_CHECK, S_BUSY_WAIT} states = 0;
                
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
            
            ctl_sd_data_shift = 0;
            ctl_data_shift_in = 0;
            ctl_clear_data_receive_reg = 0;
            
            ctl_clear_mem_addr_2nd = 0; 
            ctl_inc_mem_addr_2nd = 0;
            ctl_mem_2nd_port_wr = 0;
            
            ctl_set_done = 0;
            
            ctl_load_time_out_counter = 0;
            ctl_load_data_length_16 = 0;
            ctl_load_data_length_512 = 0;
            ctl_dec_data_count = 0;
            
            ctl_clear_response_bits_received = 0;
            
            ctl_crc_sync_reset = 0;
            ctl_crc_input_en = 0;
            
            ctl_set_ret_ok = 0;
            ctl_set_ret_crc_fail = 0;
            ctl_set_ret_time_out = 0;
            
            ctl_load_mem_to_reg = 0;
            
            ctl_init_data_out_2nd_reg = 0;
            
            ctl_load_tx_counter_for_byte = 0;
            
            ctl_load_crc_to_reg = 0;
            
            ctl_load_tx_counter_for_two_byte = 0;
            
            ctl_inc_tx_byte_counter = 0;
        
            case (1'b1) // synthesis parallel_case 
                
                current_state[S_IDLE]: begin
                    ctl_cs_high = 1'b1;
                    ctl_sck_on = 1'b1;
                    ctl_clear_data_receive_reg = 1'b1;
                    
                    if (start) begin
                        next_state [S_CS_LOW] = 1'b1;
                    end else begin
                        next_state [S_IDLE] = 1'b1;
                    end
                end
                
                current_state [S_CS_LOW] : begin
                    ctl_sck_on = 1'b1;
                    ctl_cs_low = 1'b1;
                    next_state [S_CS_LOW_WAIT] = 1'b1;
                end
                
                current_state [S_CS_LOW_WAIT] : begin
                    if (sck_pulse) begin
                        next_state [S_DATA_TX_WAIT] = 1'b1;
                    end else begin
                        next_state [S_CS_LOW_WAIT] = 1'b1;
                    end
                end
                
                current_state [S_DATA_TX_WAIT] : begin
                    if (sck_pulse) begin
                        next_state [S_DATA_TX] = 1'b1;
                    end else begin
                        next_state [S_DATA_TX_WAIT] = 1'b1;
                    end
                end
                
                current_state [S_DATA_TX] : begin
                    ctl_sd_data_shift = 1'b1;
                    ctl_load_time_out_counter = 1'b1;
                    
                    if (!tx_counter) begin
                        next_state [S_WAIT_RESPONSE] = 1'b1;
                    end else begin
                        next_state [S_DATA_TX_WAIT] = 1'b1;
                    end
                end
                
                current_state [S_WAIT_RESPONSE] : begin
                    
                    ctl_clear_mem_addr_2nd = 1'b1;
                    ctl_crc_sync_reset = 1'b1;
                    
                    if ((~sd_data_out) & (~spi_clk_d1) & (spi_clk)) begin
                        ctl_data_shift_in = 1'b1;
                        next_state [S_RECEIVE] = 1'b1;
                    end else if (!time_out_counter) begin
                        ctl_set_done = 1'b1;
                        ctl_set_ret_time_out = 1'b1;
                        next_state[S_IDLE] = 1'b1;
                    end else begin
                        next_state [S_WAIT_RESPONSE] = 1'b1;
                    end
                end
                
                current_state [S_RECEIVE] : begin
                    ctl_data_shift_in = (~spi_clk_d1) & (spi_clk);
                    
                    ctl_init_data_out_2nd_reg = 1'b1;
                    
                    if (((~spi_clk_d2) & (spi_clk_d1) & (~(|response_bits_received[2 : 0]))) && (cmd_reg != 24)) begin
                        ctl_inc_mem_addr_2nd = 1'b1;
                        ctl_mem_2nd_port_wr = 1'b1;
                    end
                    
                    if (response_bits_received == {response_bytes, 3'b000}) begin
                        if ((cmd_reg == 17) || (cmd_reg == 9) || (cmd_reg == 10))  begin
                            next_state [S_READ_PREPARE] = 1'b1;
                        end else if (cmd_reg == 24) begin // write one block
                            next_state [S_WRITE_PREPARE] = 1'b1;
                        end else begin
                            ctl_set_ret_ok = 1'b1;
                            ctl_set_done = 1'b1;
                            next_state [S_IDLE] = 1'b1;
                        end
                    end else begin
                        next_state [S_RECEIVE] = 1'b1;
                    end     
                end
                
                current_state [S_READ_PREPARE] : begin
                    ctl_clear_mem_addr_2nd = 1'b1;
                    //ctl_crc_sync_reset = 1'b1;
                    //ctl_load_time_out_counter = 1'b1;
                    
                    if (cmd_reg == 17) begin
                        ctl_load_data_length_512 = 1'b1;
                    end else begin
                        ctl_load_data_length_16 = 1'b1;
                    end
                    
                    next_state [S_READ_WAIT] = 1'b1;
                end
                
                current_state [S_READ_WAIT] : begin
                    
                    ctl_clear_response_bits_received = 1'b1;
                    
                    if ((~spi_clk_d2) & (spi_clk_d1) & (~sd_data_out)) begin
                        next_state [S_READ] = 1'b1;
                    //end else if (!time_out_counter) begin
                    //  ctl_set_done = 1'b1;
                    //  ctl_set_ret_time_out = 1'b1;
                    //  next_state[S_IDLE] = 1'b1; 
                    end else begin
                        next_state [S_READ_WAIT] = 1'b1;
                    end
                end
                
                current_state [S_READ] : begin
                    ctl_data_shift_in = (~spi_clk_d1) & (spi_clk);
                    
                    if ((~spi_clk_d2) & (spi_clk_d1) & (~(|response_bits_received[2 : 0]))) begin
                        ctl_inc_mem_addr_2nd = 1'b1;
                        ctl_mem_2nd_port_wr = 1'b1;
                        ctl_crc_input_en = 1'b1;
                        ctl_dec_data_count = 1'b1;
                    end
                    
                    if (data_length_in_bytes == 0) begin
                        next_state [S_CRC_HIGH] = 1'b1;
                    end else begin
                        next_state [S_READ] = 1'b1;
                    end
                    
                end
                
                current_state [S_CRC_HIGH] : begin
                    ctl_data_shift_in = (~spi_clk_d1) & (spi_clk);
                    
                    if ((~spi_clk_d2) & (spi_clk_d1) & (~(|response_bits_received[2 : 0]))) begin
                        ctl_crc_input_en = 1'b1;
                        next_state [S_CRC_LOW] = 1'b1;
                    end else begin
                        next_state [S_CRC_HIGH] = 1'b1;
                    end
                end
                
                current_state [S_CRC_LOW] : begin
                    ctl_data_shift_in = (~spi_clk_d1) & (spi_clk);
                    
                    if ((~spi_clk_d2) & (spi_clk_d1) & (~(|response_bits_received[2 : 0]))) begin
                        ctl_crc_input_en = 1'b1;
                        next_state [S_CRC_CHECK] = 1'b1;
                    end else begin
                        next_state [S_CRC_LOW] = 1'b1;
                    end
                end
                
                current_state [S_CRC_CHECK] : begin
                    if (!crc_out) begin
                        ctl_set_ret_ok = 1'b1;
                    end else begin
                        ctl_set_ret_crc_fail = 1'b1;
                    end
                    
                    ctl_set_done = 1'b1;
                    next_state [S_IDLE] = 1'b1;
                end
                
                current_state [S_WRITE_PREPARE] : begin
                    ctl_load_mem_to_reg = 1'b1;
                    ctl_load_tx_counter_for_byte = 1'b1;
                    next_state [S_WRITE_WAIT] = 1'b1;
                end
                
                current_state [S_WRITE_WAIT] : begin
                    if (sck_pulse) begin
                        ctl_crc_input_en = 1'b1;
                        next_state [S_WRITE] = 1'b1;
                    end else begin
                        next_state [S_WRITE_WAIT] = 1'b1;
                    end
                end
                
                current_state [S_WRITE] : begin
                    ctl_sd_data_shift = 1'b1;
                    if (!tx_counter) begin
                        ctl_inc_mem_addr_2nd = 1'b1;
                        ctl_inc_tx_byte_counter = 1'b1;
                        next_state [S_WRITE_CHECK] = 1'b1;
                    end else begin
                        next_state [S_WRITE_WAIT] = 1'b1;
                    end
                end
                
                current_state [S_WRITE_CHECK] : begin
                    if (tx_byte_counter == 513) begin
                        ctl_load_tx_counter_for_two_byte = 1'b1;
                        ctl_load_crc_to_reg = 1'b1;
                        next_state[S_SEND_CRC_WAIT] = 1'b1;                     
                    end else begin
                        next_state [S_WRITE_PREPARE] = 1'b1;
                    end
                end
                
                current_state [S_SEND_CRC_WAIT] : begin
                    if (sck_pulse) begin
                        next_state [S_SEND_CRC] = 1'b1;
                    end else begin
                        next_state [S_SEND_CRC_WAIT] = 1'b1;
                    end
                end
                
                current_state [S_SEND_CRC] : begin
                    ctl_sd_data_shift = 1'b1;
                    ctl_clear_response_bits_received = 1'b1;
                    
                    if (!tx_counter) begin
                        next_state [S_DATA_RESPONSE] = 1'b1;
                    end else begin
                        next_state [S_SEND_CRC_WAIT] = 1'b1;
                    end
                end
                
                current_state [S_DATA_RESPONSE] : begin
                    
                    ctl_data_shift_in = (~spi_clk_d1) & (spi_clk);
                    
                    if (response_bits_received == 8) begin
                        next_state [S_DATA_RESPONSE_CHECK] = 1'b1;
                    end else begin
                        next_state [S_DATA_RESPONSE] = 1'b1;
                    end
                    
                end
                
                current_state [S_DATA_RESPONSE_CHECK] : begin
                    
                    case (data_receive_reg [4 : 0]) // synthesis parallel_case 
                        5'b00101 : begin
                            ctl_set_ret_ok = 1'b1;
                        end
                        
                        5'b01011 : begin
                            ctl_set_ret_crc_fail = 1'b1;
                        end
                        
                        default : begin
                            ctl_set_ret_time_out = 1'b1;
                        end
                        
                    endcase
                    
                    next_state [S_BUSY_WAIT] = 1'b1;
                        
                end
                
                current_state [S_BUSY_WAIT] : begin
                    if ((~spi_clk_d2) & (spi_clk_d1) & (sd_data_out)) begin
                        ctl_set_done = 1'b1;
                        next_state [S_IDLE] = 1'b1; 
                    end else begin
                        next_state [S_BUSY_WAIT] = 1'b1;
                    end
                end
                
                default: begin
                    next_state[S_IDLE] = 1'b1;
                end
                
            endcase
              
        end : state_machine_comb    
    

endmodule :SD_SPI

`default_nettype wire
