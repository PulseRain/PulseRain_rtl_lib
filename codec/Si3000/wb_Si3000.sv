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
//    Wishbone wrapper for Silicon Labs, Si3000 voice codec
//    Digital Interface mode 0 is used. And do the following at top level
//
//     assign Si3000_SCLK = (Si3000_RESET_N) ? 1'bZ : 1'b0;
//     assign Si3000_SDO = (Si3000_FSYNC_N) ? 1'b0 : 1'bZ;
//
// References:
//   [1] Si3000, VoiceBand CODEC with Microphone/Speaker Drive, Rev 1.4,
//       Silicon Labs, 12/2010
//=============================================================================

`include "common.svh"
`include "Si3000.svh"

`default_nettype none

module wb_Si3000 #(parameter MCLK_DENOM = 1, MCLK_NUMER = 24, WORD_SIZE = 16,
        REG_ADDR_WRITE_DATA_LOW,
        REG_ADDR_WRITE_DATA_HIGH,
        REG_ADDR_READ_DATA_LOW,
        REG_ADDR_READ_DATA_HIGH,
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
        // interrupt
        //=======================================================================
        output logic                                fsync_pulse,
        
        //=======================================================================
        // Si3000 pins
        //=======================================================================
        
        input   wire                                Si3000_SDO,
        output  wire                                Si3000_SDI,
        input   wire                                Si3000_SCLK,
        output  wire                                Si3000_MCLK,
        input   wire                                Si3000_FSYNC_N,
        output  logic                               Si3000_RESET_N
);


    
    
    //=======================================================================
    // Signals 
    //=======================================================================
        logic                                       sync_reset;

        logic                                       Si3000_enable;
        
        logic unsigned [7 : 0]                      write_data_reg_low;
        logic unsigned [7 : 0]                      write_data_reg_high;
        
        logic unsigned [15 : 0]                     read_data_reg;

        wire  unsigned [15 : 0]                     read_data;
        wire                                        done;
        logic                                       done_d1;
        wire                                        done_pulse;
            
        wire                                        we;
        wire                                        re;
            
        wire  unsigned [7 : 0]                      write_addr;
        wire  unsigned [7 : 0]                      read_addr;
            
        logic                                       wr_busy_flag;
        logic                                       data_avail_flag;
            
        wire  unsigned [7 : 0]                      csr;
            
        wire                                        write_data_grasp;
        logic unsigned [7 : 0]                      dat_o_mux;
        
        logic                                       Si3000_reset_n_i;
            
        
        wire                                        fsync;
    //=======================================================================
    // registers and flags
    //=======================================================================
        
        assign we = stb_i & we_i;
        assign re = stb_i & (~we_i);
        assign write_addr = adr_wr_i;
        assign read_addr  = adr_rd_i;
            
        always_ff @(posedge clk, negedge reset_n) begin : write_data_reg_low_proc
            if (!reset_n) begin
                write_data_reg_low <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_WRITE_DATA_LOW)))) begin
                write_data_reg_low <= dat_i;
            end
        end : write_data_reg_low_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : write_data_reg_high_proc
            if (!reset_n) begin
                write_data_reg_high <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_WRITE_DATA_HIGH)))) begin
                write_data_reg_high <= dat_i;   
            end
        end : write_data_reg_high_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : read_data_reg_proc
            if (!reset_n) begin
                read_data_reg <= 0;
            end else if (done_pulse) begin
                read_data_reg <= read_data;
            end
        end : read_data_reg_proc
        
        
        
        
    //=======================================================================
    // control and status registers
    //=======================================================================
            
        always_ff @(posedge clk, negedge reset_n) begin : wr_busy_flag_proc
            if (!reset_n) begin
                wr_busy_flag <= 0;
            end else if (sync_reset | write_data_grasp) begin
                wr_busy_flag <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_WRITE_DATA_LOW)))) begin
                wr_busy_flag <= 1'b1;
            end
        end : wr_busy_flag_proc
                
        always_ff @(posedge clk, negedge reset_n) begin : data_avail_flag_proc
            if (!reset_n) begin
                data_avail_flag <= 0;
            end else if (sync_reset) begin
                data_avail_flag <= 0;
            end else if (done_pulse) begin
                data_avail_flag <= 1'b1;
            end else if (re & (~(|(read_addr ^ REG_ADDR_READ_DATA_LOW)))) begin
                data_avail_flag <= 0;
            end
        end : data_avail_flag_proc
            
        always_ff @(posedge clk, negedge reset_n) begin : csr_proc
            if (!reset_n) begin
                sync_reset   <= 0;
                Si3000_enable <= 0;
                Si3000_reset_n_i <= 0;
                
            end else if (we & (~(|(write_addr ^ REG_ADDR_CSR)))) begin
                sync_reset      <= dat_i[0];
                Si3000_enable   <= dat_i[1];
                Si3000_reset_n_i  <= dat_i[7];
            end else begin
                sync_reset    <= 0;
            end
        end : csr_proc
        
        always_ff @(posedge clk, negedge reset_n) begin : delay_proc
            if (!reset_n) begin
                Si3000_RESET_N <= 0;
                done_d1 <= 0;
            end else begin
                Si3000_RESET_N <= Si3000_reset_n_i;
                done_d1 <= done;
            end
        end : delay_proc
            
        assign done_pulse = (~done_d1) & done;
        assign csr = {3'd0, done, data_avail_flag, wr_busy_flag, Si3000_enable, 1'b0};
        
    //=======================================================================
    // Output Mux 
    //=======================================================================
        assign ack_o = stb_i;
        assign dat_o = dat_o_mux;
            
        always_comb begin
            
            case (read_addr) // synthesis parallel_case
                
                REG_ADDR_READ_DATA_LOW : begin
                    dat_o_mux = read_data_reg [7 : 0];
                end
                
                REG_ADDR_READ_DATA_HIGH : begin
                    dat_o_mux = read_data_reg [15 : 8];
                end
                
                default : begin
                    dat_o_mux = csr;
                end
                
            endcase
        end
            
    //=======================================================================
    // interrupt
    //=======================================================================
    
        always_ff @(posedge clk, negedge reset_n) begin : fsync_pulse_proc
            if (!reset_n) begin
                fsync_pulse <= 0;
            end else begin
                fsync_pulse <= fsync;
            end
        end : fsync_pulse_proc
        
            
    //=======================================================================
    // Si3000
    //=======================================================================
        
        Si3000 #(.MCLK_DENOM (MCLK_DENOM), 
                 .MCLK_NUMER (MCLK_NUMER), 
                 .WORD_SIZE  (WORD_SIZE)) Si3000_i (.*,
                .sync_reset (sync_reset),
                .mclk_enable (Si3000_enable),
        
                .write_data ({write_data_reg_high, write_data_reg_low}),
                
                .write_data_grasp (write_data_grasp),
                .read_data (read_data),
                
                .done (done),
            
                .Si3000_SDO     (Si3000_SDO),
                .Si3000_SDI     (Si3000_SDI),
                .Si3000_SCLK    (Si3000_SCLK),
                .Si3000_MCLK    (Si3000_MCLK),
                .Si3000_FSYNC_N (Si3000_FSYNC_N),
                .fsync_out (fsync)

        );
        
endmodule : wb_Si3000


`default_nettype wire
