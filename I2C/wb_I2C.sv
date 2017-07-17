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
//   Wishbone wrapper for I2C.  
//=============================================================================


`include "common.svh"
`include "I2C.svh"

`default_nettype none

module wb_I2C #(REG_ADDR_CSR, REG_ADDR_DATA) (
        
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
        // I2C interface
        //=======================================================================
        
        input wire                                      sda_in, 
        input wire                                      scl_in,
        
        output wire                                     sda_out,
        output wire                                     scl_out,
         
        output logic                                    irq
      
        
);
    
    //=======================================================================
    // Signals 
    //=======================================================================
        logic                                       csr_we;
        logic                                       i2c_start;
        logic                                       i2c_stop;
        
        logic                                       r1w0;
        logic                                       master1_slave0;                                       
        
        wire  unsigned [DATA_WIDTH - 1 : 0]         master_read_data;
        logic unsigned [DATA_WIDTH - 1 : 0]         read_data_reg;
        logic unsigned [DATA_WIDTH - 1 : 0]         csr_control_reg;
        
        logic                                       we;

        //  wire                                                     re;
        
        logic unsigned [DATA_WIDTH - 1 : 0]         write_addr;
        wire  unsigned [DATA_WIDTH - 1 : 0]         read_addr;
        
        logic unsigned [DATA_WIDTH - 1 : 0]         dat_o_mux;
        
        logic unsigned [DATA_WIDTH - 1 : 0]         dat_i_reg;
        
        
        logic                                       i2c_sync_reset;
        logic unsigned [DATA_WIDTH - 1 : 0]         addr_or_data_to_write_reg;
        logic                                       addr_or_data_load;
        
        wire                                        master_data_request;
        wire                                        master_data_ready;
        
        wire                                        master_no_ack_flag;
        wire                                        master_idle_flag;
        
        wire                                        master_sda_out;
        wire                                        master_scl_out;
        
        wire                                        slave_data_request;
        wire                                        slave_data_ready;
        
        wire                                        slave_no_ack_flag;
        
        wire                                        slave_sda_out;
        wire                                        slave_scl_out;
        
        logic                                       main_sda_out;
        logic                                       main_scl_out;
        logic                                       irq_enable;
        logic                                       restart;
        
        wire  unsigned [DATA_WIDTH - 1 : 0]         incoming_data;
        wire                                        i2c_slave_addr_match;
        logic                                       i2c_master_start;
        logic                                       i2c_slave_start;
        logic                                       irq_i;
    //=======================================================================
    //  data register / output mux
    //=======================================================================
       // assign re = stb_i & (~we_i);
        assign read_addr  = adr_rd_i;
        
        always_ff @(posedge clk, negedge reset_n) begin : rw_proc
            if (!reset_n) begin
                we         <= 0;
                write_addr <= 0;
                dat_i_reg  <= 0;
            end else begin
                we         <= stb_i & we_i;
                write_addr <= adr_wr_i;
                dat_i_reg  <= dat_i;
            end
        end : rw_proc
        
        
        always_ff @(posedge clk, negedge reset_n) begin : data_csr_proc
            if (!reset_n) begin
                csr_we <= 0;
                csr_control_reg <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_CSR)))) begin
                csr_we <= 1'b1;
                csr_control_reg <= dat_i_reg;
            end else begin
                csr_we <= 0;
                csr_control_reg <= 0;
            end 
        end : data_csr_proc
            
        
        always_ff @(posedge clk, negedge reset_n) begin : addr_or_data_to_write_reg_proc
            if (!reset_n) begin
                addr_or_data_to_write_reg <= 0;
                addr_or_data_load <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_DATA)))) begin
                addr_or_data_to_write_reg <= dat_i_reg;
                addr_or_data_load <= 1'b1;
            end else begin
                addr_or_data_load <= 0;
            end
            
        end : addr_or_data_to_write_reg_proc
        
        
            
            
        always_ff @(posedge clk, negedge reset_n) begin : csr_control_reg_proc
            if (!reset_n) begin
                i2c_start         <= 0;
                i2c_stop          <= 0;
                r1w0              <= 0;
                master1_slave0    <= 0;
                i2c_sync_reset    <= 0;
                irq_enable        <= 0;
                restart           <= 0;
            end else begin
                
                i2c_sync_reset    <= csr_control_reg [I2C_CSR_ADDR_SYNC_RESET_INDEX];
                i2c_start         <= csr_control_reg [I2C_CSR_ADDR_START1_STOP0_BIT_INDEX];
                
                if (csr_we) begin
                    i2c_stop       <= ~(csr_control_reg [I2C_CSR_ADDR_START1_STOP0_BIT_INDEX]);
                    r1w0           <= csr_control_reg [I2C_CSR_ADDR_R1W0_BIT_INDEX];
                    master1_slave0 <= csr_control_reg [I2C_CSR_ADDR_MASTER1_SLAVE0_BIT_INDEX];
                    irq_enable     <= csr_control_reg [I2C_CSR_ADDR_IRQ_ENABLE_BIT_INDEX];
                    restart        <= csr_control_reg [I2C_CSR_ADDR_RESTART_BIT_INDEX];
                end 
            end
        end : csr_control_reg_proc
        
        
        
        assign ack_o = stb_i;
        assign dat_o = dat_o_mux;
        
        always_comb begin
                        
            casex (read_addr)  // synthesis parallel_case 
                REG_ADDR_DATA : begin
                    dat_o_mux = read_data_reg;
                end
            
                REG_ADDR_CSR : begin
                    dat_o_mux = {master_idle_flag, master_no_ack_flag, master_data_ready, master_data_request,
                                slave_no_ack_flag, slave_data_ready, slave_data_request, i2c_slave_addr_match};
                end
                
                default : begin
                    dat_o_mux = 0;  
                end
            
            endcase
        end
        
 
        always_ff @(posedge clk, negedge reset_n) begin : read_data_reg_proc
            if (!reset_n) begin
                read_data_reg <= 0;
            end else if (master1_slave0) begin
                read_data_reg <= master_read_data;
            end else begin
                read_data_reg <= incoming_data;
            end
        end : read_data_reg_proc
           
    //=======================================================================
    //  main / slave i2c interface
    //=======================================================================
        always_ff @(posedge clk, negedge reset_n) begin : i2c_proc
            if (!reset_n) begin
                main_sda_out <= 0;
                main_scl_out <= 0;
            end else begin
                
                if (master1_slave0) begin
                    main_sda_out <= master_sda_out;
                    main_scl_out <= master_scl_out;
                end else begin
                    main_sda_out <= slave_sda_out;
                    main_scl_out <= slave_scl_out;
                end
                
            end
        end : i2c_proc
        
        assign sda_out = main_sda_out;
        assign scl_out = main_scl_out;
        
    //=======================================================================
    //  irq
    //=======================================================================
        always_ff @(posedge clk, negedge reset_n) begin : irq_proc
            if (!reset_n) begin
                irq   <= 0;
                irq_i <= 0;
            end else begin
                irq   <= irq_i;
                irq_i <= irq_enable & (slave_data_request | slave_data_ready);
            end
        end : irq_proc
        
    
    //=======================================================================
    //  irq
    //=======================================================================
        always_ff @(posedge clk, negedge reset_n) begin : i2c_start_proc
            if (!reset_n) begin
                i2c_master_start <= 0;
                i2c_slave_start  <= 0;
            end else begin
                i2c_master_start <= i2c_start & master1_slave0;
                i2c_slave_start  <= i2c_start & (~master1_slave0);
            end
        end : i2c_start_proc
        
    //=======================================================================
    //  i2c master
    //=======================================================================
                
        I2C_Master #(.CLK_DIV_FACTOR (I2C_STANDARD_DIV_FACTOR)) i2c_master_i ( // For 96MHz clock, 96Mhz / 960 = 100KHz
                .*,
                .sync_reset (i2c_sync_reset),
                
                .start (i2c_master_start),
                .stop (i2c_stop),
                .restart (restart),
                .read1_write0 (r1w0),
                
                .addr_or_data_to_write (addr_or_data_to_write_reg),
                
                .addr_or_data_load (addr_or_data_load),
                
                .data_request (master_data_request),
                .data_ready (master_data_ready),
        
                .data_read_reg (master_read_data),
                
                .no_ack_flag (master_no_ack_flag),
                .idle_flag (master_idle_flag),
                
                .sda_in (sda_in),
                .scl_in (scl_in),
                .sda_out (master_sda_out),
                .scl_out (master_scl_out)
        
        );
    
    //=======================================================================
    //  i2c slave
    //=======================================================================
           
        I2C_Slave i2c_slave_i ( // For 96MHz clock, 96Mhz / 960 = 100KHz
                .*,
                .sync_reset (i2c_sync_reset),
                
                .start (i2c_slave_start),
                .stop (i2c_stop),
                
                .outbound_data (addr_or_data_to_write_reg),
                
                .addr_or_data_load (addr_or_data_load),
                
                .data_request (slave_data_request),
                .i2c_addr_match (i2c_slave_addr_match), 
                .data_ready (slave_data_ready),
        
                .incoming_data_reg (incoming_data),
                
                .no_ack_flag (slave_no_ack_flag),
                     
                .sda_in (sda_in),
                .scl_in (scl_in),
                
                .sda_out (slave_sda_out),
                .scl_out (slave_scl_out)
            );
        
endmodule : wb_I2C

`default_nettype wire
