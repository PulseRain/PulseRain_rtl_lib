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


`ifndef M23XX1024_SVH
`define M23XX1024_SVH

`include "common.svh"

    parameter unsigned [7 : 0] M23XX1024_CMD_READ   = 8'h03;
    parameter unsigned [7 : 0] M23XX1024_CMD_WRITE  = 8'h02;
    parameter unsigned [7 : 0] M23XX1024_CMD_EDIO   = 8'h3B;
    parameter unsigned [7 : 0] M23XX1024_CMD_EQIO   = 8'h38;
    parameter unsigned [7 : 0] M23XX1024_CMD_RSTIO  = 8'hFF;
    parameter unsigned [7 : 0] M23XX1024_CMD_RDMR   = 8'h05;
    parameter unsigned [7 : 0] M23XX1024_CMD_WRMR   = 8'h01;
    
    parameter unsigned [1 : 0] M23XX1024_BYTE_MODE  = 2'b00;
    parameter unsigned [1 : 0] M23XX1024_PAGE_MODE  = 2'b10;
    parameter unsigned [1 : 0] M23XX1024_SEQ_MODE   = 2'b01;
    
    
    
extern module M23XX1024 #(parameter CLK_SCK_RATIO = 6) (

    input   wire                                clk,
    input   wire                                reset_n,
    
    input   wire                                sync_reset,
    
    input   wire                                instruction_start,
    input   wire unsigned [7 : 0]               instruction,
    input   wire unsigned [23 : 0]              address,
    input   wire unsigned [7 : 0]               write_data,
    
    output  logic                               write_data_grasp,
    
    output  logic                               read_data_enable_out,
    output  logic unsigned [7 : 0]              read_data,
    
    input   wire                                mem_so,
    output  logic                               mem_si,
    output  wire                                mem_hold_n,
    output  wire                                mem_cs_n, 
    output  logic                               mem_sck
);  
    
extern module wb_M23XX1024 #(parameter CLK_SCK_RATIO = 6, 
                      REG_ADDR_INSTRUCTION,
                      REG_ADDR_DATA,
                      REG_ADDR_ADDRESS2,
                      REG_ADDR_ADDRESS1,
                      REG_ADDR_ADDRESS0,
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
        // M23XX1024 pins
        //=======================================================================
        
        
        input   wire                                mem_so,
        output  wire                                mem_si,
        output  wire                                mem_hold_n,
        output  wire                                mem_cs_n, 
        output  wire                                mem_sck
);
    
`endif
