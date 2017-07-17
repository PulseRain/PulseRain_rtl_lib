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


`ifndef I2C_SVH
`define I2C_SVH

`include "common.svh"

    parameter int I2C_CSR_ADDR_SYNC_RESET_INDEX         = 0;
    parameter int I2C_CSR_ADDR_START1_STOP0_BIT_INDEX   = 1;
    parameter int I2C_CSR_ADDR_R1W0_BIT_INDEX           = 2;
    parameter int I2C_CSR_ADDR_MASTER1_SLAVE0_BIT_INDEX = 3;
    parameter int I2C_CSR_ADDR_RESTART_BIT_INDEX        = 4;
   
    parameter int I2C_CSR_ADDR_IRQ_ENABLE_BIT_INDEX     = 7;
    
    
    
    parameter int I2C_DATA_LEN = 8;
    parameter unsigned [4 : 0] I2C_10BIT_LEADING_PATTERN = 5'b11110;
    
    parameter int I2C_STANDARD_DIV_FACTOR = ACTUAL_CLK_RATE / 100000;

    parameter int I2C_SLAVE_ADDR_LENGTH = 7;

 extern module wb_I2C #(REG_ADDR_CSR, REG_ADDR_DATA) (
        
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
        // I2C interface
        //=======================================================================
        
        input wire                                      sda_in, 
        input wire                                      scl_in,
        
        output wire                                     sda_out,
        output wire                                     scl_out,
         
        output logic                                    irq
      
        
);   
     
extern module I2C_Master #(parameter CLK_DIV_FACTOR = 960) ( // For 96MHz clock, 96Mhz / 960 = 100KHz
        input  wire                             clk,
        input  wire                             reset_n,
        input  wire                             sync_reset,
        
        input  wire                             start,
        input  wire                             stop,
        input  wire                             restart,
        input  wire                             read1_write0,
        
        input  wire [7 : 0]                     addr_or_data_to_write,
        
        input  wire                             addr_or_data_load,
        output logic                            data_request,
        
        
        output logic                                    data_ready,
        
        output logic unsigned [I2C_DATA_LEN - 1 : 0]    data_read_reg,
        
        output logic                            no_ack_flag,
        output logic                            idle_flag,
        
        input  wire                             sda_in,
        input  wire                             scl_in,
        output logic                            sda_out,
        output logic                            scl_out
        
);
    
extern module I2C_Slave  ( // For 96MHz clock, 96Mhz / 960 = 100KHz
        input  wire                             clk,
        input  wire                             reset_n,
        input  wire                             sync_reset,
        
        input  wire                             start,
        input  wire                             stop,
        
        input  wire [I2C_DATA_LEN - 1 : 0]      outbound_data,
        
        input  wire                             addr_or_data_load,
        output logic                            data_request,
        
         output logic                            i2c_addr_match, 
        output logic                                    data_ready,
        
        output logic unsigned [I2C_DATA_LEN - 1 : 0]    incoming_data_reg,
        
        output logic                            no_ack_flag,
        
        input  wire                             sda_in,
        input  wire                             scl_in,
        output logic                            sda_out,
        output logic                            scl_out
);
    
`endif
