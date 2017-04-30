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
//   Wishbone wrapper for Serial 8051
//=============================================================================


`include "common.svh"

`default_nettype none

module wb_Serial_8051
        #(parameter STABLE_TIME, MAX_BAUD_PERIOD, REG_ADDR_SCON, REG_ADDR_SBUF, FIFO_SIZE = 4) (
    
    //=======================================================================
    // clock / reset
    //=======================================================================
        
        input  wire                                 clk,
        input  wire                                 reset_n,
    
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
    // Timer Pulse Input
    //=======================================================================
        input   wire                                class_8051_unit_pulse,
        input   wire                                timer_trigger,
        
        input   wire                                UART_RXD,
        output  wire                                UART_TXD,
        
        output  wire                                SCON_TI, 
        output  wire                                SCON_RI
    
);
    //=======================================================================
    // Signals 
    //=======================================================================
        wire                                        reg_SCON_ack_o;
        wire                                        reg_SBUF_ack_o;
        logic unsigned [DATA_WIDTH - 1 : 0]         dat_o_mux;  
                
        wire  unsigned [DATA_WIDTH - 1 : 0]         write_addr;
          // wire  unsigned [DATA_WIDTH - 1 : 0]         read_addr;
          
        
        logic                                       UART_start_TX;
        //  logic                                       UART_start_RX;
    
        logic                                       UART_RI_d1, UART_TI_d1;
        wire                                        UART_RI, UART_TI;
        
        wire                                        we;
        wire  unsigned [DATA_WIDTH - 1 : 0]         UART_SBUF_received;
        wire  unsigned [DATA_WIDTH - 1 : 0]         data_in, uart_rx_fifo_top_data_out;
        wire                                        uart_rx_fifo_not_empty;
        
        logic unsigned [DATA_WIDTH - 1 : 0]         SBUF, SCON, SCON_d1;
            
        wire                                        SCON_SM0, SCON_SM1, SCON_SM2, SCON_REN;
      //  wire                                        SCON_TB8;
        //  wire                                        SCON_RB8;
        
       
        
        wire                                        RI_rising;
        logic                                       SCON_write;
    //=======================================================================
    // Output Mux 
    //=======================================================================
        assign ack_o = stb_i;
        assign dat_o = dat_o_mux;
        
        always_comb begin
            if (adr_rd_i == REG_ADDR_SCON) begin
                dat_o_mux = SCON;
            end else begin
                dat_o_mux = SBUF;
            end
        end
        
    //=======================================================================
    // Regsiters 
    //=======================================================================
            
        assign we = stb_i & we_i;
        assign write_addr = adr_wr_i;
       // assign read_addr  = adr_rd_i;
        assign data_in = dat_i;
        
        // UART_RI_d1, UART_TI_d1
        always_ff @(posedge clk, negedge reset_n) begin : UART_TI_RI_delay_proc
            if (!reset_n) begin
                UART_RI_d1 <= 0;
                UART_TI_d1 <= 0;
            end else begin
                UART_RI_d1 <= UART_RI;
                UART_TI_d1 <= UART_TI;
            end
        end : UART_TI_RI_delay_proc
            
        always_ff @(posedge clk, negedge reset_n) begin : SBUF_proc
            if (!reset_n) begin
                SBUF <= 0;
                UART_start_TX <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_SBUF)))) begin
                SBUF <= data_in;
                UART_start_TX <= 1'b1;
            end else if (uart_rx_fifo_not_empty & SCON_REN) begin
                SBUF <= uart_rx_fifo_top_data_out;
                UART_start_TX <= 0;
            end else begin
                UART_start_TX <= 0;
            end
        end : SBUF_proc
    
        /*
        always_ff @(posedge clk, negedge reset_n) begin : UART_start_RX_proc
            if (!reset_n) begin
                UART_start_RX <= 0;
            end else if ( ((~SCON_REN_d1) & SCON_REN) || (read_addr == REG_ADDR_SBUF) ) begin
                UART_start_RX <= 1'b1;
            end else begin
                UART_start_RX <= 0;
            end
        end : UART_start_RX_proc
    */
        
          /*
        always_ff @(posedge clk, negedge reset_n) begin : UART_start_RX_proc
            if (!reset_n) begin
                UART_start_RX <= 0;
            end else if ( ((~SCON_REN_d1) & SCON_REN) || RI_rising) begin
                UART_start_RX <= 1'b1;
            end else begin
                UART_start_RX <= 0;
            end
        end : UART_start_RX_proc
  */        
    
        always_ff @(posedge clk, negedge reset_n) begin : SCON_proc
            if (!reset_n) begin
                SCON          <= 0;
                SCON_write    <= 0;
            end else begin
                SCON_write    <= 0;
                
                if (we & (~(|(write_addr ^ REG_ADDR_SCON)))) begin
                    SCON <= data_in;
                    SCON_write <= 1'b1; 
                end else begin
                    
                    if (!SCON_write) begin 
                        SCON [0] <= uart_rx_fifo_not_empty;
                    end
                    
                    if ((~UART_TI_d1) & UART_TI) begin
                        SCON [1] <= (~UART_TI_d1) & UART_TI;
                    end
                    
                end 
            end
        end : SCON_proc
    
        always_ff @(posedge clk, negedge reset_n) begin
            if (!reset_n) begin
                SCON_d1 <= 0;
            end else begin
                SCON_d1 <= SCON;
            end
        end
          
                     
        assign SCON_SM0 = SCON[7];
        assign SCON_SM1 = SCON[6];
        assign SCON_SM2 = SCON[5];
        assign SCON_REN = SCON[4];
        assign SCON_TI  = SCON[1];
        assign SCON_RI  = SCON[0];
            
    //=======================================================================
    // UART 
    //=======================================================================
    
        Serial_8051 #(.STABLE_TIME (STABLE_TIME), 
                      .MAX_BAUD_PERIOD (MAX_BAUD_PERIOD)) 
            uart_rx (.*,
                .start_TX (1'b0),
                .start_RX (1'b1), //UART_start_RX),
                
                .class_8051_unit_pulse (class_8051_unit_pulse),
                .timer_trigger (timer_trigger),
                
                .RXD (UART_RXD),
                .SBUF_in (8'd0),
                .SM ({SCON_SM2, SCON_SM1, SCON_SM0}),
                .REN (1'b1),
                .TXD (),
                .SBUF_out (UART_SBUF_received),
                .TI (),
                .RI (UART_RI)
        );
        
        Serial_8051 #(.STABLE_TIME (STABLE_TIME), 
                      .MAX_BAUD_PERIOD (MAX_BAUD_PERIOD)) 
            uart_tx (.*,
                .start_TX (UART_start_TX),
                .start_RX (1'b0),
                
                .class_8051_unit_pulse (class_8051_unit_pulse),
                .timer_trigger (timer_trigger),
                
                .RXD (1'b0),
                .SBUF_in (SBUF),
                .SM ({SCON_SM2, SCON_SM1, SCON_SM0}),
                .REN (1'b0),
                .TXD (UART_TXD),
                .SBUF_out (),
                .TI (UART_TI),
                .RI ()
        );
        
    //=======================================================================
    // UART_RX_FIFO 
    //=======================================================================
        assign RI_rising = ((~UART_RI_d1) & UART_RI);
        
        UART_RX_FIFO #(.FIFO_SIZE (FIFO_SIZE)) uart_rx_fifo_i (.*,
                .fifo_write (RI_rising),
                .fifo_data_in (UART_SBUF_received),
                
                .fifo_read (SCON_d1 [0] & (~SCON[0])),
                .fifo_top_data_out (uart_rx_fifo_top_data_out),
                
                .fifo_not_empty (uart_rx_fifo_not_empty),
                .fifo_full (),
                .fifo_count ()
        );  
        
endmodule : wb_Serial_8051

`default_nettype wire
