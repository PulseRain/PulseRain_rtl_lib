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
//  Single Clock Memory  
//
// References:
//  [1] Altera Quartus II Handbook Ver 12.0, Vol 1
//=============================================================================

`default_nettype none

`include "block_memory.svh"


// tailored from Ref[1]
module single_clk_ram 
        #( parameter DATA_WIDTH = 8,  
                     ADDR_WIDTH = 8) (
        output logic [DATA_WIDTH - 1:0] q,
        input wire [DATA_WIDTH - 1:0] d,
        input wire [ADDR_WIDTH - 1:0] write_address, read_address,
        input wire  we, clk
        );
    
    localparam MEM_SIZE = 2**ADDR_WIDTH;
    
    logic [DATA_WIDTH - 1:0] mem [MEM_SIZE - 1:0];
    
    always_ff @ (posedge clk) begin
        if (we)
            mem[write_address] <= d;
        q <= mem[read_address]; // q doesn't get d in this clock cycle
    end
endmodule


module single_clk_mem_wrapper   
        #( parameter DATA_WIDTH = 8,  
                     ADDR_WIDTH = 8)(
      
    //=======  clock and reset ======
        input wire                      clk,
    //========== INPUT ==========

        input wire                      write_enable,
        input wire                      read_enable,
        
        input wire [DATA_WIDTH - 1 : 0] data_in,
        input wire [ADDR_WIDTH - 1 : 0] write_address, read_address,

    //========== OUTPUT ==========
        output logic                      enable_out,
        output logic [DATA_WIDTH - 1 : 0] data_out
        
    //========== IN/OUT ==========
);

    
    single_clk_ram #(.DATA_WIDTH(DATA_WIDTH),
                     .ADDR_WIDTH(ADDR_WIDTH)) 
                    mem (.clk (clk),
                         .we (write_enable),
                         .write_address (write_address),
                         .read_address (read_address),
                         .d (data_in),
                         .q (data_out));
                    
     always_ff @(posedge clk) begin
        enable_out <= read_enable;
     end
   
endmodule : single_clk_mem_wrapper

`default_nettype wire
