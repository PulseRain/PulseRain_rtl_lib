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
//    Wishbone wrapper for Altera MAX10 ADC 
//=============================================================================

`include "common.svh"
`include "ADC.svh"

`default_nettype none

module wb_MAX10_ADC #(REG_ADDR_DATA_HIGH,
                      REG_ADDR_DATA_LOW,
                      REG_ADDR_CSR) (
        
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
        // ADC pins
        //=======================================================================
        
        input  wire                                 adc_pll_clock_clk,                   
        input  wire                                 adc_pll_locked_export,               
        output logic                                adc_data_ready
        
);

    //=======================================================================
    // Signals 
    //=======================================================================

        logic unsigned [11 : 0]                     data_reg;
        wire  unsigned [11 : 0]                     response_data;
        
        logic                                       we;
        wire                                        re;
        
        logic  unsigned [7 : 0]                     write_addr;
        wire  unsigned [7 : 0]                      read_addr;
        
        logic                                       command_valid;
        logic unsigned [4 : 0]                      command_channel;
        logic                                       command_ready;
        
        wire  unsigned [7 : 0]                      csr;
        
        logic unsigned [7 : 0]                      dat_o_mux;
        
    //=======================================================================
    // data register
    //=======================================================================
        
      //  assign we = stb_i & we_i;
        assign re = stb_i & (~we_i);
     //   assign write_addr = adr_wr_i;
        assign read_addr  = adr_rd_i;
        
        always_ff @(posedge clk, negedge reset_n) begin : rw_proc
            if (!reset_n) begin
                we <= 0;
                write_addr <= 0;
            end else begin
                we <= stb_i & we_i;
                write_addr <= adr_wr_i;
            end
        end : rw_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : data_reg_proc
            if (!reset_n) begin
                data_reg <= 0;
            end else if (command_ready) begin
                data_reg <= response_data;
            end
        end : data_reg_proc
        
    //=======================================================================
    // control and status registers
    //=======================================================================
        
        
        always_ff @(posedge clk, negedge reset_n) begin : csr_proc
            if (!reset_n) begin
                command_channel <= 0;
                command_valid   <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_CSR)))) begin
                command_channel <= dat_i[7 : 3];
                command_valid   <= dat_i[0];
            end 
            
        end : csr_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : adc_data_ready_proc
            if (!reset_n) begin
                adc_data_ready <= 0;
            end else if (command_ready) begin
                adc_data_ready <= 1'b1;
            end else if (re & (~(|(read_addr ^ REG_ADDR_CSR)))) begin
                adc_data_ready <= 0;
            end
        end : adc_data_ready_proc
        
        assign csr = {command_channel, 1'b0, adc_data_ready, command_valid};
        
    //=======================================================================
    // Output Mux 
    //=======================================================================
        assign ack_o = stb_i;
        assign dat_o = dat_o_mux;
        
        always_comb begin
            if (read_addr == REG_ADDR_DATA_HIGH) begin
                dat_o_mux = {4'd0, data_reg [11 : 8]};
            end else if (read_addr == REG_ADDR_DATA_LOW) begin
                dat_o_mux = data_reg [7 : 0];
            end else begin
                dat_o_mux = csr;
            end
        end
        
    
    //=======================================================================
    // MAX10 ADC
    //=======================================================================
        ADC ADC_i (
            .adc_pll_clock_clk (adc_pll_clock_clk),   
            .adc_pll_locked_export (adc_pll_locked_export),  
        
            .clock_clk (clk),             
            .command_valid (command_valid),  
            .command_channel (command_channel),
            .command_startofpacket (1'b0),  
            .command_endofpacket (1'b0),    
            .command_ready (command_ready), 
            .reset_sink_reset_n (reset_n),  
            .response_valid (),         
            .response_channel (),       
            .response_data (response_data),
            .response_startofpacket (), 
            .response_endofpacket () 
        );
        

endmodule : wb_MAX10_ADC


`default_nettype wire
