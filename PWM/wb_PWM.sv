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
//    Wishbone wrapper for PWM
//=============================================================================


`include "common.svh"
`include "PWM.svh"


`default_nettype none

module wb_PWM #(parameter NUM_OF_PWM, 
                      REG_ADDR_CSR,
                      REG_ADDR_DATA
                      ) (

        
        //=======================================================================
        // clock / reset
        //=======================================================================
        
        input   wire                                clk,
        input   wire                                reset_n,

        //=======================================================================
        // Wishbone Interface (FASM synchronous RAM dual port model)
        //=======================================================================
            
        input  wire                                 stb_i,
        input  wire                                 we_i,
        
        input  wire  unsigned [DATA_WIDTH - 1 : 0]  adr_wr_i,
        input  wire  unsigned [DATA_WIDTH - 1 : 0]  adr_rd_i,
        input  wire  unsigned [DATA_WIDTH - 1 : 0]  dat_i,
        output wire  unsigned [DATA_WIDTH - 1 : 0]  dat_o,
        output wire                                 ack_o,
    
        //=======================================================================
        // PWM output
        //=======================================================================
        output wire unsigned [NUM_OF_PWM - 1 : 0]    pwm_out 
        
);


    
    
    //=======================================================================
    // Signals 
    //=======================================================================
        logic unsigned [NUM_OF_PWM - 1 : 0][7 : 0]  reg_on;
        logic unsigned [NUM_OF_PWM - 1 : 0][7 : 0]  reg_off;
        
    
      
        logic                                       we;
        logic                                       re;
        
        logic  unsigned [7 : 0]                     write_addr;
        logic  unsigned [7 : 0]                     read_addr;
        logic  unsigned [7 : 0]                     dat_i_reg;
        
        
        logic unsigned [NUM_OF_PWM - 1 : 0][7 : 0]  reg_resolution_high;
        logic unsigned [NUM_OF_PWM - 1 : 0][7 : 0]  reg_resolution_low;
        wire  unsigned [NUM_OF_PWM - 1 : 0][15 : 0] resolution;
      
        logic unsigned [NUM_OF_PWM - 1 : 0][15 : 0] pwm_counter;
        logic unsigned [NUM_OF_PWM - 1 : 0]         pwm_pulse;
        
        logic unsigned [7 : 0]                      reg_data_internal;
        logic unsigned [7 : 0]                      reg_csr;
        wire  unsigned [$clog2(NUM_OF_PWM) - 1 : 0] pwm_index;
        wire                                        pwm_reg_write;       
        
        wire  unsigned [2 : 0]                      sub_addr;
        logic unsigned [NUM_OF_PWM - 1 : 0]         pwm_sync_reset;
            
    //=======================================================================
    // registers and flags
    //=======================================================================
        
        //assign we = stb_i & we_i;
        assign re = stb_i & (~we_i);
        //assign write_addr = adr_wr_i;
        assign read_addr  = adr_rd_i;
        
        always_ff @(posedge clk, negedge reset_n) begin : rw_proc
            if (!reset_n) begin
                we <= 0;
        //      re <= 0;
                write_addr <= 0;
        //      read_addr <= 0;
                dat_i_reg <= 0;
            end else begin
                we <= stb_i & we_i;
        //      re <= stb_i & (~we_i);
                write_addr <= adr_wr_i;
        //      read_addr  <= adr_rd_i;
                dat_i_reg <= dat_i;
    
            end
            
        end : rw_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : reg_data_internal_proc
            if (!reset_n) begin
                reg_data_internal <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_DATA)))) begin
                reg_data_internal <= dat_i_reg;  
            end 
        end : reg_data_internal_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : reg_csr_proc
            if (!reset_n) begin
                reg_csr <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_CSR)))) begin
                reg_csr <= dat_i_reg;  
            end else begin
                reg_csr <= 0;
            end
        end : reg_csr_proc
        
        
        assign pwm_index = reg_csr[$high(pwm_index) : 0];
        assign pwm_reg_write = reg_csr[7];
        assign sub_addr = reg_csr[6 : 4];
        
        
        
        genvar i;
        generate 
            for (i = 0; i < NUM_OF_PWM; i = i + 1) begin : pwm_gen
                always_ff @(posedge clk, negedge reset_n) begin : reg_on_proc
                    if (!reset_n) begin
                        reg_on[i][7 : 0] <= 0;
                    end else if (pwm_reg_write && (sub_addr == PWM_SUB_ADDR_REG_ON) && (pwm_index == i)) begin
                        reg_on[i][7 : 0] <= reg_data_internal;
                    end
                    
                end : reg_on_proc
                
                always_ff @(posedge clk, negedge reset_n) begin : reg_off_proc
                    if (!reset_n) begin
                        reg_off[i][7 : 0] <= 0;
                    end else if (pwm_reg_write && (sub_addr == PWM_SUB_ADDR_REG_OFF) && (pwm_index == i)) begin
                        reg_off[i][7 : 0] <= reg_data_internal;
                    end
                end : reg_off_proc
                
                always_ff @(posedge clk, negedge reset_n) begin : pwm_sync_reset_proc
                    if (!reset_n) begin
                        pwm_sync_reset[i] <= 0;
                    end else if (pwm_reg_write && (sub_addr == PWM_SUB_ADDR_SYNC_RESET) && (pwm_index == i)) begin
                        pwm_sync_reset[i] <= 1'b1;
                    end else begin
                        pwm_sync_reset[i] <= 0;
                    end
                end : pwm_sync_reset_proc
                
                
                
                always_ff @(posedge clk, negedge reset_n) begin : reg_resolution_high_proc
                    if (!reset_n) begin
                        reg_resolution_high[i][7 : 0] <= 0;
                    end else if (pwm_reg_write && (sub_addr == PWM_SUB_ADDR_RESOLUTION_HIGH)) begin
                        reg_resolution_high[i][7 : 0] <= reg_data_internal;
                    end
                end : reg_resolution_high_proc
        
                always_ff @(posedge clk, negedge reset_n) begin : reg_resolution_low_proc
                    if (!reset_n) begin
                        reg_resolution_low[i][7 : 0] <= 0;
                    end else if (pwm_reg_write && (sub_addr == PWM_SUB_ADDR_RESOLUTION_LOW)) begin
                        reg_resolution_low[i][7 : 0] <= reg_data_internal;
                    end
                end : reg_resolution_low_proc
                
                assign resolution[i][15 : 0] = {reg_resolution_high[i][7 : 0], reg_resolution_low[i][7 : 0]};
                        
                
                
                
                
                always_ff @(posedge clk, negedge reset_n) begin : pwm_counter_proc
                    if (!reset_n) begin
                        pwm_counter[i][15 : 0] <= 0;
                    end else if (pwm_counter[i][15 : 0] > 0) begin
                        pwm_counter[i][15 : 0] <= pwm_counter[i][15 : 0] -  16'd1;
                    end else begin
                        pwm_counter[i][15 : 0] <= resolution[i][15 : 0];
                    end
                end : pwm_counter_proc
        
                always_ff @(posedge clk, negedge reset_n) begin : pwm_pulse_proc
                    if (!reset_n) begin
                        pwm_pulse[i] <= 0;
                    end else if (pwm_counter[i][15 : 0] == 1) begin
                        pwm_pulse[i] <= 1'b1;
                    end else begin
                        pwm_pulse[i] <= 0;
                    end
                end : pwm_pulse_proc
                  
                
                PWM_core  PWM_core (.*,
                    .sync_reset (pwm_sync_reset[i]),
                    .pwm_pulse (pwm_pulse),
                    .pwm_on_reg (reg_on[i][7 : 0]),
                    .pwm_off_reg (reg_off[i][7 : 0]),
                    .pwm_out (pwm_out[i])
                );
                
                    
            end : pwm_gen
        endgenerate
        
        
        
    

endmodule : wb_PWM


`default_nettype wire
