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
//    Wishbone wrapper for flash read 
//=============================================================================

`include "common.svh"
`include "flash_read.svh"


`default_nettype none

module wb_flash_read #(parameter REG_ADDR_CSR, REG_ADDR_DATA) (

        
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
        // pins to/from flash read IP 
        //=======================================================================
        output wire                                flash_read_req,
        output wire unsigned [23 : 0]              flash_addr_read,
        input  wire                                flash_read_en_in,
        input  wire unsigned [7 : 0]               flash_byte_in
);

    //=======================================================================
    // Signals 
    //=======================================================================
        logic                                       we;
        logic                                       re;

        logic  unsigned [7 : 0]                     write_addr;
        logic  unsigned [7 : 0]                     read_addr;
        
        logic  unsigned [7 : 0]                     data_in_reg;
        
        logic                                       flash_load_enable;
        wire                                        done;
        
        logic  unsigned [23 : 0]                    addr_out;
        logic                                       data_avail;
        logic  unsigned [7 : 0]                     dat_o_mux;
        logic  unsigned [7 : 0]                     flash_data;
        
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

        always_ff @(posedge clk, negedge reset_n) begin : addr_proc
            if (!reset_n) begin
                addr_out <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_DATA)))) begin
                addr_out  <= {addr_out[$high(addr_out) - 8 : 0], data_in_reg};
            end 
        end : addr_proc
        
        assign flash_read_req  = flash_load_enable;
        assign flash_addr_read = addr_out;
        
        always_ff @(posedge clk, negedge reset_n) begin : flash_load_enable_proc
            if (!reset_n) begin
                flash_load_enable <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_CSR)))) begin
                flash_load_enable <= 1'b1;
            end else begin
                flash_load_enable <= 0;
            end
        end : flash_load_enable_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : data_avail_proc
            if (!reset_n) begin
                data_avail <= 0;
            end else if (flash_load_enable) begin
                data_avail <= 0;
            end else if (flash_read_en_in) begin
                data_avail <= 1'b1;
            end
        end : data_avail_proc

      
        always_ff @(posedge clk, negedge reset_n) begin : flash_data_proc
            if (!reset_n) begin
                flash_data <= 0;
            end else if (flash_read_en_in) begin
                flash_data <= flash_byte_in;
            end
        end : flash_data_proc


        assign ack_o = stb_i;
        assign dat_o = dat_o_mux;
        
        always_comb begin

            casex (read_addr)  // synthesis parallel_case 
                REG_ADDR_DATA : begin
                    dat_o_mux = flash_data;
                end

                REG_ADDR_CSR : begin
                    dat_o_mux = {7'd0, data_avail};
                end

                default : begin
                    dat_o_mux = 0;  
                end

            endcase
        end

        
endmodule : wb_flash_read


`default_nettype wire
