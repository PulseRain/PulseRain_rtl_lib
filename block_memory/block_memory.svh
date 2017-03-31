`ifndef BLOCK_MEMORY_SVH
`define BLOCK_MEMORY_SVH


extern module single_clk_ram 
        #( parameter DATA_WIDTH = 8,  
                     ADDR_WIDTH = 8) (
        output logic [DATA_WIDTH - 1:0] q,
        input wire [DATA_WIDTH - 1:0] d,
        input wire [ADDR_WIDTH - 1:0] write_address, read_address,
        input wire  we, clk
);
    
extern module single_clk_mem_wrapper   
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

`endif
