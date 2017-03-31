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
//    Wishbone wrapper for Microchip 23A1024/23LC1024 Serial SRAM 
//
// References:
//   [1] 23A1024/23LC1024, 1Mbit SPI Serial SRAM with SDI and SQI Interface
//       Microchip Technology, Inc. 2011
//=============================================================================


`include "common.svh"
`include "M23XX1024.svh"

`default_nettype none

module wb_M23XX1024 #(parameter CLK_SCK_RATIO = 6, 
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


    
    
    //=======================================================================
    // Signals 
    //=======================================================================
        logic                                       sync_reset;
        logic unsigned [7 : 0]                      data_reg;
        
        wire                                        read_data_enable_out;
        wire  unsigned [7 : 0]                      read_data;
        
        logic                                       we;
        logic                                       re;
        
        logic unsigned [23 : 0]                     address;
        logic unsigned [7 : 0]                      instruction;
        logic                                       instruction_start;
        
        logic  unsigned [7 : 0]                     write_addr;
        logic  unsigned [7 : 0]                     read_addr;
        logic  unsigned [7 : 0]                     dat_i_reg;
        
        logic                                       wr_busy_flag;
        logic                                       data_avail_flag;
        
        wire  unsigned [7 : 0]                      csr;
        
        wire                                        write_data_grasp;
        logic unsigned [7 : 0]                      dat_o_mux;
        
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
        
        
        always_ff @(posedge clk, negedge reset_n) begin : data_reg_proc
            if (!reset_n) begin
                data_reg <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_DATA)))) begin
                data_reg <= dat_i_reg;  
            end else if (read_data_enable_out) begin
                data_reg <= read_data;
            end
        end : data_reg_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : address_proc
            if (!reset_n) begin
                address <= 0;
            end else begin
                if (we & (~(|(write_addr ^ REG_ADDR_ADDRESS2)))) begin
                    address[23 : 16] <= dat_i_reg;
                end
                
                if (we & (~(|(write_addr ^ REG_ADDR_ADDRESS1)))) begin
                    address[15 : 8] <= dat_i_reg;
                end
                
                if (we & (~(|(write_addr ^ REG_ADDR_ADDRESS0)))) begin
                    address[7 : 0] <= dat_i_reg;
                end
            end
            
        end : address_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : instruction_proc
            if (!reset_n) begin
                instruction <= 0;
                instruction_start <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_INSTRUCTION)))) begin
                instruction <= dat_i_reg;
                instruction_start <= 1'b1;
            end else begin
                instruction_start <= 0;
            end
        end : instruction_proc
        
    //=======================================================================
    // control and status registers
    //=======================================================================
        
        
        always_ff @(posedge clk, negedge reset_n) begin : wr_busy_flag_proc
            if (!reset_n) begin
                wr_busy_flag <= 0;
            end else if (sync_reset | write_data_grasp) begin
                wr_busy_flag <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_DATA)))) begin
                wr_busy_flag <= 1'b1;
            end
        end : wr_busy_flag_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : data_avail_flag_proc
            if (!reset_n) begin
                data_avail_flag <= 0;
            end else if (sync_reset | (re & (~(|(read_addr ^ REG_ADDR_DATA))))) begin
                data_avail_flag <= 0;
            end else if (read_data_enable_out) begin
                data_avail_flag <= 1'b1;
            end
        end : data_avail_flag_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : sync_reset_proc
            if (!reset_n) begin
                sync_reset <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_CSR)))) begin
                sync_reset <= dat_i_reg[0];
            end else begin
                sync_reset <= 0;
            end
        end : sync_reset_proc
        
        assign csr = {4'd0, ~mem_cs_n, data_avail_flag, wr_busy_flag, 1'b0};
        
    //=======================================================================
    // Output Mux 
    //=======================================================================
        assign ack_o = stb_i;
        assign dat_o = dat_o_mux;
        
        always_comb begin
            if (read_addr == REG_ADDR_DATA) begin
                dat_o_mux = data_reg;
            end else begin
                dat_o_mux = csr;
            end
        end
        
    
    //=======================================================================
    // M23XX1024
    //=======================================================================
        
        M23XX1024 #(.CLK_SCK_RATIO(CLK_SCK_RATIO)) M23XX1024_i (.*,
            .sync_reset (sync_reset),
            .instruction_start (instruction_start),
            .instruction (instruction),
            .address (address),
            .write_data (data_reg),
            
            .write_data_grasp (write_data_grasp),
            
            .read_data_enable_out (read_data_enable_out),
            .read_data (read_data),
            
            .mem_so (mem_so),
            .mem_si (mem_si),
            .mem_hold_n (mem_hold_n),
            .mem_cs_n (mem_cs_n),
            .mem_sck (mem_sck)
        );  
        
    

endmodule : wb_M23XX1024


`default_nettype wire
