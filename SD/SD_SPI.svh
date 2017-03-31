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



`ifndef SD_SPI_SVH
`define SD_SPI_SVH

`include "common.svh"

    parameter unsigned [5 : 0] SD_CMD0  = 6'h00;
    parameter unsigned [5 : 0] SD_CMD8  = 6'h08;

    parameter unsigned [1 : 0] SD_R1_R1B = 2'b00;
    parameter unsigned [1 : 0] SD_R2     = 2'b01;
    parameter unsigned [1 : 0] SD_R3_R7  = 2'b10;
    
    
    parameter unsigned [1 : 0] SD_RET_OK       = 2'b11;
    parameter unsigned [1 : 0] SD_RET_TIME_OUT = 2'b01;
    parameter unsigned [1 : 0] SD_RET_CRC_FAIL = 2'b10;
    
    
    
    

extern  module SD_SPI #(parameter SD_CLK_SLOW_SCK_RATIO = 480, SD_CLK_FAST_SCK_RATIO = 12,
                                  BUFFER_SIZE_IN_BYTES = 1024) (
    input wire                                  clk,
    input wire                                  reset_n,
    
    input   wire                                sync_reset,
    input wire unsigned [1 : 0]                 response_type,
    input wire                                  sclk_slow0_fast1,
    
    
    input wire  start,
    input wire unsigned [5 : 0]                 cmd,
    input wire unsigned [31 : 0]                arg,
    
    input wire unsigned [$clog2(BUFFER_SIZE_IN_BYTES) - 1 : 0]  addr_base,
    
    input wire                                                  mem_wr,
    input wire unsigned [$clog2(BUFFER_SIZE_IN_BYTES) - 1 : 0]  mem_addr,
    input wire unsigned [7 : 0]                                 data_in,
    
    output wire                                                 data_en_out,
    output logic    unsigned [7 : 0]                            data_out,
    
    output logic                                cs_n = 1'b1,
    output logic                                spi_clk,
    input  wire                                 sd_data_out,
    output logic                                sd_data_in,
    output logic                                done,
    output logic unsigned [1 : 0]               ret_status
    
);
    
    
    
extern module wb_SD #(parameter SD_CLK_SLOW_SCK_RATIO = 480, 
                         SD_CLK_FAST_SCK_RATIO = 6, 
                         BUFFER_SIZE_IN_BYTES = 1024,
        
        REG_ADDR_CSR,
        REG_ADDR_CMD,
        REG_ADDR_ARG0,
        REG_ADDR_ARG1,
        REG_ADDR_ARG2,
        REG_ADDR_ARG3,

        REG_ADDR_BUF_ADDR,
        REG_ADDR_DATA_IN,
        REG_ADDR_DATA_OUT) (

        
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
        // SD pins
        //=======================================================================
        
            output wire                                 cs_n,
            output wire                                 spi_clk,
            input  wire                                 sd_data_out,
            output wire                                 sd_data_in
    
            
);

    
`endif
