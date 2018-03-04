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
//    Wishbone wrapper for incremental rotary encoder
//=============================================================================


`include "common.svh"
`include "rotary_encoder.svh"


`default_nettype none

module wb_rotary_encoder #(parameter REG_ADDR_COUNTER, COUNTER_BITS = 8, DEBOUNCE_DELAY = 100000, COUNTER_CLK_DECREASE = 1
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
        // pins from the incremental rotary encoder 
        //=======================================================================
        input   wire                                encoder_clk,
        input   wire                                encoder_dt,
        input   wire                                encoder_sw
        
);


    //=======================================================================
    // Signals 
    //=======================================================================
      
        logic                                       we;
        logic                                       re;
        
        logic  unsigned [7 : 0]                     write_addr;
        logic  unsigned [7 : 0]                     read_addr;
        logic  unsigned [DATA_WIDTH - 1 : 0]        counter_reg;
        logic  unsigned [DATA_WIDTH - 1 : 0]        dat_i_reg;
        wire   unsigned [DATA_WIDTH - 1 : 0]        counter_out;
        
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
        
        always_ff @(posedge clk, negedge reset_n) begin : counter_reg_proc
            if (!reset_n) begin
                counter_reg <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_COUNTER)))) begin
                counter_reg <= dat_i_reg;  
            end 
        end : counter_reg_proc
        
        
        assign ack_o = stb_i;
        assign dat_o = counter_out;
                
             
        rotary_encoder # (.COUNTER_BITS (COUNTER_BITS), .DEBOUNCE_DELAY (DEBOUNCE_DELAY), .COUNTER_CLK_DECREASE (COUNTER_CLK_DECREASE)) rotary_encoder_i (.*,
            .counter_init (1'b0),
            .counter_in (counter_reg),
            .counter_out (counter_out)
);

endmodule : wb_rotary_encoder

`default_nettype wire
