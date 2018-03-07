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
//    Wishbone wrapper for PS2 
//=============================================================================

`include "common.svh"
`include "PS2.svh"


`default_nettype none

module wb_PS2 #(parameter REG_ADDR_CSR, REG_ADDR_DATA) (

        
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
        // pins from the PS2 port 
        //=======================================================================
            
        input   wire                                ps2_clk,
        input   wire                                ps2_dat,
        
        //=======================================================================
        // interrupt
        //=======================================================================
        output logic                                data_available
);




    //=======================================================================
    // Signals 
    //=======================================================================
        logic                                       we;
        logic                                       re;

        logic  unsigned [7 : 0]                     write_addr;
        logic  unsigned [7 : 0]                     read_addr;
        logic                                       ps2_sync_reset;
        logic                                       int_clear;
        
        wire                                        ps2_keyboard_enable_out;
        wire   unsigned [7 : 0]                     ps2_keyboard_data_out;

        logic  unsigned [7 : 0]                     data_out_reg;
        //logic  unsigned [2 : 0]                     ps2_keyboard_enable_out_sr;
        logic unsigned [DATA_WIDTH - 1 : 0]         dat_o_mux;
        
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
                
            end else begin
                we <= stb_i & we_i;
        //      re <= stb_i & (~we_i);
                write_addr <= adr_wr_i;
        //      read_addr  <= adr_rd_i;


            end

        end : rw_proc

        always_ff @(posedge clk, negedge reset_n) begin : ps2_sync_reset_proc
            if (!reset_n) begin
                ps2_sync_reset <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_DATA)))) begin
                ps2_sync_reset <= 1'b1;
            end else begin
                ps2_sync_reset <= 0;
            end 
        end : ps2_sync_reset_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : int_clear_proc
            if (!reset_n) begin
                int_clear <= 0;
             end else if (we & (~(|(write_addr ^ REG_ADDR_CSR)))) begin
                int_clear <= 1'b1;
            end else begin
                int_clear <= 0;
            end 
        end : int_clear_proc

        
        always_ff @(posedge clk, negedge reset_n) begin : data_out_reg_proc
            if (!reset_n) begin
                data_out_reg <= 0;
            end else if (ps2_keyboard_enable_out) begin
                data_out_reg <= ps2_keyboard_data_out;
            end;
        end : data_out_reg_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : data_available_proc
            if (!reset_n) begin
                data_available <= 0;
            end else if (int_clear) begin
                data_available <= 0;
            end else if (ps2_keyboard_enable_out) begin
                data_available <= 1'b1;
            end 
        
        end : data_available_proc
        
        
      //  always_ff @(posedge clk, negedge reset_n) begin : sr_proc
      //      if (!reset_n) begin
      //          ps2_keyboard_enable_out_sr <= 0;
      //      end else begin
      //          ps2_keyboard_enable_out_sr <= 
      //              {ps2_keyboard_enable_out_sr [$high(ps2_keyboard_enable_out_sr) - 1 : 0], ps2_keyboard_enable_out};
      //      end
      //  end : sr_proc
        
        
        

        assign ack_o = stb_i;
        assign dat_o = dat_o_mux;
        
        always_comb begin
                                
            casex (read_addr)  // synthesis parallel_case 
                REG_ADDR_DATA : begin
                    dat_o_mux = data_out_reg;
                end

                REG_ADDR_CSR : begin
                    dat_o_mux = {7'd0, data_available};
                end

                default : begin
                    dat_o_mux = 0;  
                end

            endcase
        end

        ps2_keyboard ps2_keyboard_i (.*,
            .sync_reset (ps2_sync_reset),

            .ps2_clk (ps2_clk),
            .ps2_dat (ps2_dat),

            .enable_out (ps2_keyboard_enable_out),
            .data_out (ps2_keyboard_data_out)
        );

endmodule : wb_PS2


`default_nettype wire
