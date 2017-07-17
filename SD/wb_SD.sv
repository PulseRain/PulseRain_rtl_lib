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
//    Wishbone wrapper for SD card
//=============================================================================

//`include "SD_SPI.svh"

`default_nettype none

module wb_SD #(parameter SD_CLK_SLOW_SCK_RATIO = 480, 
                         SD_CLK_FAST_SCK_RATIO = 6, 
                         BUFFER_SIZE_IN_BYTES = 1024,
        
        REG_ADDR_CSR,
        REG_ADDR_CMD,
        REG_ADDR_ARG0,
        REG_ADDR_ARG1,
        REG_ADDR_ARG2,
        REG_ADDR_ARG3,

        REG_ADDR_BUF_ADDR,
        REG_ADDR_DATA_IN,
        REG_ADDR_DATA_OUT) (

        
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
            
            input  wire  unsigned [8 - 1 : 0]  adr_wr_i,
            input  wire  unsigned [8 - 1 : 0]  adr_rd_i,
            input  wire  unsigned [8 - 1 : 0]  dat_i,
            output wire  unsigned [8 - 1 : 0]  dat_o,
            output wire                                 ack_o,
    
        //=======================================================================
        // SD pins
        //=======================================================================
        
            output wire                                 cs_n,
            output wire                                 spi_clk,
            input  wire                                 sd_data_out,
            output wire                                 sd_data_in
    
            
);

    
    //=======================================================================
    // Signals 
    //=======================================================================
            logic                                       we;
          //  logic                                       re;
        
            logic  unsigned [7 : 0]                     write_addr;
            logic  unsigned [7 : 0]                     read_addr;
        
            logic                                       sync_reset;
            logic                                       sd_start;
            logic unsigned [5 : 0]                      cmd_reg;
            logic unsigned [7 : 0]                      arg0_reg;
            logic unsigned [7 : 0]                      arg1_reg;
            logic unsigned [7 : 0]                      arg2_reg;
            logic unsigned [7 : 0]                      arg3_reg;
            
            logic unsigned [9 : 0]                      buffer_addr;
            logic                                       inc_addr;
            logic                                       mem_wr;
            logic unsigned [7 : 0]                      data_out_reg;
            logic unsigned [7 : 0]                      data_in_reg;
            
            wire                                        sd_spi_data_en_out;
            wire  unsigned [7 : 0]                      data_received;
            logic unsigned [7 : 0]                      dat_o_mux;
            logic unsigned [7 : 0]                      dat_i_reg;
          //  wire  unsigned [7 : 0]                      csr;
        
            logic unsigned [1 : 0]                      response_type;
            logic                                       sclk_slow0_fast1;
            
            wire                                        done;
            wire  unsigned [1 : 0]                      ret_status;
            
    //=======================================================================
    // registers and control / flags
    //=======================================================================
        
        //assign we = stb_i & we_i;
      //  assign re = stb_i & (~we_i);
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
            
    
    
        always_ff @(posedge clk, negedge reset_n) begin : csr_proc
            if (!reset_n) begin
                sync_reset <= 0;
                sd_start   <= 0;
                inc_addr   <= 0;
                response_type <= 0;
                sclk_slow0_fast1 <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_CSR)))) begin
                sync_reset       <= dat_i_reg [0];
                sd_start         <= dat_i_reg [1];
                inc_addr         <= dat_i_reg [2];
                response_type    <= dat_i_reg [4 : 3];
                sclk_slow0_fast1 <= dat_i_reg [5];
            end else begin
                sync_reset <= 0;
                sd_start   <= 0;
                inc_addr   <= 0;
            end
        end : csr_proc
        
     //   assign csr = 0;
        
        always_ff @(posedge clk, negedge reset_n) begin : cmd_proc
            if (!reset_n) begin
                cmd_reg <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_CMD)))) begin
                cmd_reg <= dat_i_reg [$high(cmd_reg) : 0];
            end else if (done) begin
                cmd_reg <= '1; 
            end
            
        end : cmd_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : arg0_proc
            if (!reset_n) begin
                arg0_reg <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_ARG0)))) begin
                arg0_reg <= dat_i_reg;
            end
        end : arg0_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : arg1_proc
            if (!reset_n) begin
                arg1_reg <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_ARG1)))) begin
                arg1_reg <= dat_i_reg;
            end
        end : arg1_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : arg2_proc
            if (!reset_n) begin
                arg2_reg <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_ARG2)))) begin
                arg2_reg <= dat_i_reg;
            end
        end : arg2_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : arg3_proc
            if (!reset_n) begin
                arg3_reg <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_ARG3)))) begin
                arg3_reg <= dat_i_reg;
            end
        end : arg3_proc
        
        
        always_ff @(posedge clk, negedge reset_n) begin : buffer_addr_proc
            if (!reset_n) begin
                buffer_addr <= 0;
            //end else if ((we & (~(|(write_addr ^ REG_ADDR_CSR)))) & (~dat_i[2])) begin
            end else if ((we & (~(|(write_addr ^ REG_ADDR_CSR)))) & (~dat_i_reg[2])) begin  
                buffer_addr [9 : 8] <= dat_i_reg [7 : 6];
            end else if (we & (~(|(write_addr ^ REG_ADDR_BUF_ADDR)))) begin
                buffer_addr [7 : 0] <= dat_i_reg;
            end else if (inc_addr) begin
                buffer_addr <= buffer_addr + ($size(buffer_addr))'(1);
            end
        end : buffer_addr_proc
    
        always_ff @(posedge clk, negedge reset_n) begin : data_out_proc
            if (!reset_n) begin
                mem_wr <= 0;
                data_out_reg <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_DATA_OUT)))) begin
                mem_wr       <= 1'b1;
                data_out_reg <= dat_i_reg;
            end else begin
                mem_wr <= 0;
            end
        end : data_out_proc
    
        always_ff @(posedge clk, negedge reset_n) begin : data_in_proc
            if (!reset_n) begin
                data_in_reg <= 0;
            end else if (sd_spi_data_en_out) begin
                data_in_reg <=  data_received;
            end
        end : data_in_proc
        
    //=======================================================================
    // Output Mux 
    //=======================================================================
        assign ack_o = stb_i;
        assign dat_o = dat_o_mux;
                
        //assign dat_o_mux = data_in_reg;
        
        always_comb begin
            if (read_addr == REG_ADDR_CMD) begin
                dat_o_mux = {ret_status, cmd_reg};
            end else begin
                dat_o_mux = data_in_reg;
            end
        end
            
    //=======================================================================
    // SD_SPI
    //=======================================================================
        
        
        SD_SPI #(.SD_CLK_SLOW_SCK_RATIO (SD_CLK_SLOW_SCK_RATIO),
                 .SD_CLK_FAST_SCK_RATIO (SD_CLK_FAST_SCK_RATIO),
                 .BUFFER_SIZE_IN_BYTES (BUFFER_SIZE_IN_BYTES)) 
            sd_spi_i (.*,
            
            .sync_reset (sync_reset),
            
            .response_type (response_type),
            .sclk_slow0_fast1 (sclk_slow0_fast1),
    
            .start (sd_start),
            .cmd (cmd_reg),
            .arg ({arg3_reg, arg2_reg, arg1_reg, arg0_reg}),
            
            .addr_base (buffer_addr),
            
            .mem_wr (mem_wr),
            .mem_addr (buffer_addr),
            .data_in (data_out_reg),
            
            .data_en_out (sd_spi_data_en_out),
            .data_out (data_received),
            
            .cs_n (cs_n),
            .spi_clk (spi_clk),
            .sd_data_out (sd_data_out),
            .sd_data_in (sd_data_in),
            .done (done),
            .ret_status (ret_status));
                
endmodule : wb_SD

`default_nettype wire
