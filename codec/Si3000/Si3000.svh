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

`ifndef SI3000_SVH
`define SI3000_SVH


extern module Si3000 #(parameter MCLK_DENOM = 8, MCLK_NUMER = 375, WORD_SIZE = 16) (

    input   wire                                clk,
    input   wire                                reset_n,
    
    input   wire                                sync_reset,
    input   wire                                mclk_enable,

    input   wire unsigned [15 : 0]              write_data,
    
    output  logic                               write_data_grasp,
    output  logic unsigned [15 : 0]             read_data,
    output  logic                               done,
    
    input   wire                                Si3000_SDO,
    output  wire                                Si3000_SDI,

    input   wire                                Si3000_SCLK,
    input   wire                                Si3000_FSYNC_N,
    
    output  wire                                Si3000_MCLK,
    output  wire                                fsync_out

);

extern module wb_Si3000 #(parameter MCLK_DENOM = 1, MCLK_NUMER = 24, WORD_SIZE = 16,
        REG_ADDR_WRITE_DATA_LOW,
        REG_ADDR_WRITE_DATA_HIGH,
        REG_ADDR_READ_DATA_LOW,
        REG_ADDR_READ_DATA_HIGH,
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
        // interrupt
        //=======================================================================
        output logic                                fsync_pulse,
        
        //=======================================================================
        // Si3000 pins
        //=======================================================================
        
        input   wire                                Si3000_SDO,
        output  wire                                Si3000_SDI,
        input   wire                                Si3000_SCLK,
        output  wire                                Si3000_MCLK,
        input   wire                                Si3000_FSYNC_N,
        output  logic                               Si3000_RESET_N
);

`endif
