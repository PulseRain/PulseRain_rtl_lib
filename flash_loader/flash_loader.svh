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

`ifndef FLASH_LOADER_SVH
`define FLASH_LOADER_SVH

`include "common.svh"

    parameter int FLASH_LOADER_CSR_ADDR_BIT_INDEX    = 0;
    parameter int FLASH_LOADER_READ_BIT_INDEX        = 1;
    parameter int FLASH_LOADER_WRITE_BIT_INDEX       = 2;
    parameter int FLASH_LOADER_BUF_FILL_BIT_INDEX    = 3;
    parameter int FLASH_LOADER_SAVE_BEGIN_BIT_INDEX  = 4;
    parameter int FLASH_LOADER_SAVE_END_BIT_INDEX    = 5;
    
    parameter int FLASH_LOADER_ONCHIP_FLASH_BITS = 17;
    parameter int FLASH_LOADER_SEGMENT_SIZE_BYTES = 2048;
    parameter int FLASH_LOADER_BUFFER_BITS = $clog2(FLASH_LOADER_SEGMENT_SIZE_BYTES * 2 / 4);
    
    parameter unsigned [1 : 0]  FLASH_BUF_IDLE = 2'b00;
    parameter unsigned [1 : 0]  FLASH_BUF_BUSY = 2'b01;
    parameter unsigned [1 : 0]  FLASH_BUF_DONE = 2'b10;
    
    
    

extern module wb_flash_loader #(REG_ADDR_DATA0, 
                         REG_ADDR_DATA1,
                         REG_ADDR_DATA2,
                         REG_ADDR_DATA3,
                         REG_ADDR_CSR
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
        // Wishbone Interface (FASM synchronous RAM dual port model)
        //=======================================================================
        
        input wire                                      flash_buffer_write_enable,
        input wire [DATA_WIDTH * 4 - 1 : 0]             flash_buffer_data_in,
        input wire [FLASH_LOADER_BUFFER_BITS - 1 : 0]   flash_buffer_write_address,
        
        output  wire                                    active_flag,
        output  wire                                    done_flag,
        
        output  logic                                   ping_busy,
        output  logic                                   pong_busy
        
        
);
    
    
`endif
