/*
###############################################################################
# Copyright (c) 2018, PulseRain Technology LLC 
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
//    Wishbone wrapper for LCD 
//=============================================================================

`include "common.svh"
`include "LCD.svh"


`default_nettype none

module wb_LCD #(parameter REG_ADDR_CSR, REG_ADDR_DATA) (

        
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
        // pins for LCD, 4 line serial 
        //=======================================================================
        output  wire                                rst,
        output  wire                                csx,
        output  wire                                dcx, 
        output  wire                                scl,
        output  wire                                sda
);

    //=======================================================================
    // Signals 
    //=======================================================================
        logic                                       we;
        logic                                       re;

        logic  unsigned [7 : 0]                     write_addr;
        logic  unsigned [7 : 0]                     read_addr;
        
        logic  unsigned [7 : 0]                     data_in_reg;
        logic  unsigned [7 : 0]                     lcd_data;
        logic  unsigned [7 : 0]                     lcd_csr;
        
        logic                                       data_load;
        wire                                        done;
        logic                                       lcd_done;
        
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
                data_in_reg <= 0;
                
            end else begin
                we <= stb_i & we_i;
        //      re <= stb_i & (~we_i);
                write_addr <= adr_wr_i;
        //      read_addr  <= adr_rd_i;
                data_in_reg <= dat_i;

            end

        end : rw_proc

        always_ff @(posedge clk, negedge reset_n) begin : lcd_data_proc
            if (!reset_n) begin
                lcd_data <= 0;
                data_load <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_DATA)))) begin
                lcd_data  <= data_in_reg;
                data_load <= 1'b1;
            end else begin
                data_load <= 0;
            end 
        end : lcd_data_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : lcd_csr_proc
            if (!reset_n) begin
                lcd_csr <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_CSR)))) begin
                lcd_csr <= data_in_reg;
            end 
        end : lcd_csr_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : lcd_done_proc
            if (!reset_n) begin
                lcd_done <= 0;
            end else if (data_load) begin
                lcd_done <= 0;
            end else if (done) begin
                lcd_done <= 1'b1;
            end
        end : lcd_done_proc

        assign dcx = lcd_csr[0];
        assign rst = lcd_csr[1];
        
        ST7735R ST7735R_i (.*,
            .sync_reset (rst),
            
            .data_load (data_load),
            .data (lcd_data),
            
            .csx (csx),
            .sda (sda),
            .scl (scl),
            
            .done (done)
        );
        

        assign ack_o = stb_i;
        assign dat_o = {7'd0, lcd_done};
        
        
endmodule : wb_LCD


`default_nettype wire
