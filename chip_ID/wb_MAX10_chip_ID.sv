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
//    Wishbone wrapper for Altera MAX10 chip ID
//=============================================================================

`include "common.svh"
`include "chip_ID.svh"

`default_nettype none

module wb_Altera_chip_ID #(REG_ADDR_DATA_CSR) (
        
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
        output wire                                 ack_o
        
);
    
    
    //=======================================================================
    // Signals 
    //=======================================================================
        logic                                       we;
        wire                                        re;
        
        logic  unsigned [7 : 0]                     write_addr;
        wire  unsigned [7 : 0]                      read_addr;
        

        wire                                        chip_id_data_valid;
        wire   unsigned [63 : 0]                    chip_id;

        logic  unsigned [63 : 0]                    chip_id_reg;

        
    //=======================================================================
    // Altera IP: Altera Unique Chip ID
    //=======================================================================
    
        Altera_unique_chip_ID Altera_unique_chip_ID_i (
            .clkin (clk), 
            .reset (1'b0),
            .data_valid (chip_id_data_valid),
            .chip_id (chip_id) 
        );
        
    
    //=======================================================================
    // data register
    //=======================================================================
        
        assign re = stb_i & (~we_i);
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
        
        
        assign ack_o = stb_i;
        assign dat_o = chip_id_reg [63 : 56];
        
        always_ff @(posedge clk, negedge reset_n) begin : data_csr_proc
            if (!reset_n) begin
                chip_id_reg <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_DATA_CSR)))) begin
                chip_id_reg <= chip_id;
            end else if (re & (~(|(read_addr ^ REG_ADDR_DATA_CSR)))) begin
                chip_id_reg <= {chip_id_reg [55 : 0], 8'd0};
            end 
            
        end : data_csr_proc

endmodule : wb_Altera_chip_ID


`default_nettype wire
    