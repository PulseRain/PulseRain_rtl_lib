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
//   Wishbone wrapper for MAX10 onchip flash IP. This module is needed to 
// write image to MAX10 onchip flash in high throughput. 
//=============================================================================


`include "common.svh"
`include "flash_loader.svh"
`include "block_memory.svh"

`default_nettype none

module wb_flash_loader #(REG_ADDR_DATA0, 
                         REG_ADDR_DATA1,
                         REG_ADDR_DATA2,
                         REG_ADDR_DATA3,
                         REG_ADDR_CSR
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
        // flash interface
        //=======================================================================
        
        input wire                                      flash_buffer_write_enable,
        input wire [DATA_WIDTH * 4 - 1 : 0]             flash_buffer_data_in,
        input wire [FLASH_LOADER_BUFFER_BITS - 1 : 0]   flash_buffer_write_address,
        
        output  wire                                    active_flag,
        output  wire                                    done_flag,
        
        output  logic                                   ping_busy,
        output  logic                                   pong_busy
        
        
);
    
    //=======================================================================
    // Signals 
    //=======================================================================
        logic                                       csr_addr;
        logic unsigned [DATA_WIDTH - 1 : 0]                     csr_data_reg0;
        logic unsigned [DATA_WIDTH - 1 : 0]                     csr_data_reg1;
        logic unsigned [DATA_WIDTH - 1 : 0]                     csr_data_reg2;
        logic unsigned [DATA_WIDTH - 1 : 0]                     csr_data_reg3;
        
        wire  unsigned [31 : 0]                                 csr_data;
        
        logic unsigned [31 : 0]                     csr_read_data_reg;
        
        
        logic unsigned [DATA_WIDTH - 1 : 0]                     csr_control_reg;
        logic                                       csr_read;
        logic                                       csr_read_d1;
        logic                                       csr_write;
        wire unsigned [31 : 0]                      csr_readdata;
    
        wire unsigned [31:0]                        data_readdata;
        wire                                        waitrequest;
        wire                                        data_readdatavalid;
        
        logic                                       we;
		//  wire													 re;
        
        
        logic unsigned [DATA_WIDTH - 1 : 0]         write_addr;
        wire  unsigned [DATA_WIDTH - 1 : 0]         read_addr;
        
        logic unsigned [DATA_WIDTH - 1 : 0]         dat_o_mux;
        
        logic unsigned [DATA_WIDTH - 1 : 0]         dat_i_reg;
        logic                                       buf_fill;
        logic                                       buf_fill_start;
        logic                                       flash_save_begin_addr;
        logic                                       flash_save_end_addr;
        
        logic unsigned [FLASH_LOADER_ONCHIP_FLASH_BITS - 1 : 0] onchip_flash_address;
        logic unsigned [FLASH_LOADER_ONCHIP_FLASH_BITS - 1 : 0] onchip_write_begin_addr;
        logic unsigned [FLASH_LOADER_ONCHIP_FLASH_BITS - 1 : 0] onchip_write_end_addr;
        
        logic unsigned [1 : 0]                      flash_buffer_ping_state;
        logic unsigned [1 : 0]                      flash_buffer_pong_state;
        
        logic                                       ctl_load_onchip_flash_address;
        logic                                       ctl_inc_onchip_flash_address;
        logic                                       ctl_clear_ping_state;
        logic                                       ctl_clear_pong_state;
        
        logic                                       ctl_set_ping_free;
        logic                                       ctl_set_ping_busy;
        logic                                       ctl_set_pong_free;
        logic                                       ctl_set_pong_busy;
        
        logic                                       ctl_segment_buf_read;
        logic                                       ctl_segment_buf_read_d1;
        logic                                       ctl_clear_segment_addr_counter;
        logic                                       ctl_flip_active_ping0_pong1;
        logic                                       ctl_init_active_ping0_pong1;
        
        logic                                       active_ping0_pong1;
        logic unsigned [FLASH_LOADER_BUFFER_BITS - 2 : 0] segment_addr_counter;
        
        wire                                        flash_buffer_enable_out;
        wire  unsigned [31 : 0]                     flash_buffer_data_out;
        
        logic unsigned [31 : 0]                     flash_data_to_write;
        logic                                       flash_buffer_enable_out_d1;
        logic                                       done;
        logic                                       done_reg;
        
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
                csr_control_reg <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_CSR)))) begin
                csr_control_reg <= dat_i_reg;
            end else begin
                csr_control_reg <= 0;
            end 
        end : data_csr_proc
            
        always_ff @(posedge clk, negedge reset_n) begin : csr_data_reg0_proc
            if (!reset_n) begin
                csr_data_reg0 <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_DATA0)))) begin
                csr_data_reg0 <= dat_i_reg;
            end 
        end : csr_data_reg0_proc
            
        always_ff @(posedge clk, negedge reset_n) begin : csr_data_reg1_proc
            if (!reset_n) begin
                csr_data_reg1 <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_DATA1)))) begin
                csr_data_reg1 <= dat_i_reg;
            end 
        end : csr_data_reg1_proc
            
        
        always_ff @(posedge clk, negedge reset_n) begin : csr_data_reg2_proc
            if (!reset_n) begin
                csr_data_reg2 <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_DATA2)))) begin
                csr_data_reg2 <= dat_i_reg;
            end 
        end : csr_data_reg2_proc
         
        always_ff @(posedge clk, negedge reset_n) begin : csr_data_reg3_proc
            if (!reset_n) begin
                csr_data_reg3 <= 0;
            end else if (we & (~(|(write_addr ^ REG_ADDR_DATA3)))) begin
                csr_data_reg3 <= dat_i_reg;
            end 
        end : csr_data_reg3_proc
                
        assign csr_data = {csr_data_reg3, csr_data_reg2, csr_data_reg1, csr_data_reg0};
            
        always_ff @(posedge clk, negedge reset_n) begin : csr_control_reg_proc
            if (!reset_n) begin
                csr_addr        <= 0;
                csr_read        <= 0;
                csr_write       <= 0;
                buf_fill        <= 0;
                buf_fill_start  <= 0;
                flash_save_begin_addr <= 0;
                flash_save_end_addr   <= 0;
                done_reg <= 0;
                
            end else begin
                csr_addr  <= csr_control_reg [FLASH_LOADER_CSR_ADDR_BIT_INDEX];
                csr_read  <= csr_control_reg [FLASH_LOADER_READ_BIT_INDEX];
                csr_write <= csr_control_reg [FLASH_LOADER_WRITE_BIT_INDEX];
                buf_fill  <= csr_control_reg [FLASH_LOADER_BUF_FILL_BIT_INDEX];  
                buf_fill_start <= buf_fill;
                flash_save_begin_addr <= csr_control_reg [FLASH_LOADER_SAVE_BEGIN_BIT_INDEX];
                flash_save_end_addr   <= csr_control_reg [FLASH_LOADER_SAVE_END_BIT_INDEX];
                
                if (buf_fill) begin
                    done_reg <= 0;
                end else if (done) begin
                    done_reg <= 1'b1;
                end
            end
        end : csr_control_reg_proc
        
        
        always_ff @(posedge clk, negedge reset_n) begin : csr_read_data_reg_proc
            if (!reset_n) begin
                csr_read_d1         <= 0;
                csr_read_data_reg   <= 0;
            end else begin
                csr_read_d1 <= csr_read;
            
                if (csr_read_d1) begin
                    csr_read_data_reg <= csr_readdata;
                end
                
            end
        
        end : csr_read_data_reg_proc
        
        
        assign ack_o = stb_i;
        assign dat_o = dat_o_mux;
        
        always_comb begin
                        
            casex (read_addr)  // synthesis parallel_case 
                REG_ADDR_DATA0 : begin
                    dat_o_mux = csr_read_data_reg [7 : 0];
                end
            
                REG_ADDR_DATA1 : begin
                    dat_o_mux = csr_read_data_reg [15 : 8];
                end
                
                REG_ADDR_DATA2 : begin
                    dat_o_mux = csr_read_data_reg [23 : 16];
                end
                
                REG_ADDR_DATA3 : begin
                    dat_o_mux = csr_read_data_reg [31 : 24];
                end
                
                default : begin
                    dat_o_mux = 0;  
                end
            
            endcase
        end
        
        
    onchip_flash onchip_flash_i (
        .clock (clk),
        .avmm_csr_addr (csr_addr),
        .avmm_csr_read (csr_read),
        .avmm_csr_writedata (csr_data),
        .avmm_csr_write (csr_write),
        .avmm_csr_readdata (csr_readdata),
        
        .avmm_data_addr (onchip_flash_address),
        .avmm_data_read (1'b0),
        .avmm_data_writedata (flash_data_to_write),
        .avmm_data_write (flash_buffer_enable_out_d1),
        .avmm_data_readdata (data_readdata),
        .avmm_data_waitrequest (waitrequest),
        .avmm_data_readdatavalid (data_readdatavalid),
        .avmm_data_burstcount(2'b01),
        .reset_n (reset_n)
    );
    
    single_clk_mem_wrapper #(.DATA_WIDTH (32), .ADDR_WIDTH (FLASH_LOADER_BUFFER_BITS)) flash_buffer (.*,
        
        .write_enable (flash_buffer_write_enable),
        .read_enable (ctl_segment_buf_read_d1),
        
        .data_in (flash_buffer_data_in),
        .write_address (flash_buffer_write_address),
        
        .read_address ({active_ping0_pong1, segment_addr_counter}),
        
        .enable_out (flash_buffer_enable_out),
        .data_out (flash_buffer_data_out)
    );
    
    
    always_ff @(posedge clk, negedge reset_n) begin : active_ping0_pong1_proc
        if (!reset_n) begin
            active_ping0_pong1 <= 0;
        end else if (ctl_init_active_ping0_pong1) begin 
            active_ping0_pong1 <= 0;
        end else if (ctl_flip_active_ping0_pong1) begin
            active_ping0_pong1 <= ~active_ping0_pong1;
        end
    end : active_ping0_pong1_proc
    
        
    
    always_ff @(posedge clk, negedge reset_n) begin : onchip_flash_address_proc
        if (!reset_n) begin
            onchip_flash_address <= 0;
        end else if (ctl_load_onchip_flash_address) begin
            onchip_flash_address <= onchip_write_begin_addr;
        end else if (ctl_inc_onchip_flash_address) begin
            onchip_flash_address <= onchip_flash_address + ($size(onchip_flash_address))'(1);
        end
    end : onchip_flash_address_proc 
    
    always_ff @(posedge clk, negedge reset_n) begin : onchip_write_begin_addr_proc
        if (!reset_n) begin
            onchip_write_begin_addr <= 0;
        end else if (flash_save_begin_addr) begin
            onchip_write_begin_addr <= csr_data [$high(onchip_write_begin_addr) : 0];
        end
    end : onchip_write_begin_addr_proc
    
    
    always_ff @(posedge clk, negedge reset_n) begin : onchip_write_end_addr_proc
        if (!reset_n) begin
            onchip_write_end_addr <= 0;
        end else if (flash_save_end_addr) begin
            onchip_write_end_addr <= csr_data [$high(onchip_write_end_addr) : 0];
        end
    end : onchip_write_end_addr_proc
        
    
    always_ff @(posedge clk, negedge reset_n) begin : flash_buffer_ping_state_proc
        if (!reset_n) begin
            flash_buffer_ping_state <= 0;
        end else if (ctl_clear_ping_state) begin
            flash_buffer_ping_state <= FLASH_BUF_IDLE;
        end else if (flash_buffer_write_enable && (flash_buffer_write_address == 0)) begin
            flash_buffer_ping_state <= FLASH_BUF_BUSY;
        end else if (flash_buffer_write_enable && (flash_buffer_write_address == (FLASH_LOADER_SEGMENT_SIZE_BYTES / 4 - 1))) begin
            flash_buffer_ping_state <= FLASH_BUF_DONE;
        end
    end : flash_buffer_ping_state_proc
    
    
    always_ff @(posedge clk, negedge reset_n) begin : flash_buffer_pong_state_proc
        if (!reset_n) begin
            flash_buffer_pong_state <= 0;
        end else if (ctl_clear_pong_state) begin
            flash_buffer_pong_state <= FLASH_BUF_IDLE;
        end else if (flash_buffer_write_enable && (flash_buffer_write_address == (FLASH_LOADER_SEGMENT_SIZE_BYTES / 4))) begin
            flash_buffer_pong_state <= FLASH_BUF_BUSY;
        end else if (flash_buffer_write_enable && (flash_buffer_write_address == (FLASH_LOADER_SEGMENT_SIZE_BYTES * 2 / 4 - 1))) begin
            flash_buffer_pong_state <= FLASH_BUF_DONE;
        end
    end : flash_buffer_pong_state_proc
            
    
    always_ff @(posedge clk, negedge reset_n) begin : ping_pong_busy_proc
        if (!reset_n) begin
            ping_busy <= 0;
            pong_busy <= 0;
        end else begin
            if (ctl_set_ping_free) begin
                ping_busy <= 0;
            end else if (ctl_set_ping_busy) begin
                ping_busy <= 1'b1;
            end
            
            if (ctl_set_pong_free) begin
                pong_busy <= 0;
            end else if (ctl_set_pong_busy) begin
                pong_busy <= 1'b1;
            end
        end
    end : ping_pong_busy_proc
    
    
    always_ff @(posedge clk, negedge reset_n) begin : flash_data_to_write_proc
        
        if (!reset_n) begin
            flash_buffer_enable_out_d1 <= 0;
        end else begin 
            
            flash_buffer_enable_out_d1 <= flash_buffer_enable_out;
            
            if (flash_buffer_enable_out) begin
                flash_data_to_write <= flash_buffer_data_out;
            end
            
        end
    end : flash_data_to_write_proc
    
    always_ff @(posedge clk, negedge reset_n) begin : segment_buffer_read_proc
        if (!reset_n) begin
            segment_addr_counter <= 0;
            ctl_segment_buf_read_d1 <= 0;
        end else begin
            ctl_segment_buf_read_d1 <= ctl_segment_buf_read;
            
            if (ctl_clear_segment_addr_counter) begin
                segment_addr_counter <= 0;
            end else if (ctl_segment_buf_read_d1) begin
                segment_addr_counter <= segment_addr_counter + ($size(segment_addr_counter))'(1);
            end
            
        end
    end : segment_buffer_read_proc
    

    assign active_flag = 0;
    assign done_flag = done_reg;
    
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // FSM main
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                        
        enum {S_IDLE, S_DATA_AVAIL_CHECK, S_CHECK_WAIT_REQUEST, S_SEGMENT_BUF_READ, 
              S_WAIT_READ, S_FLASH_SEGMENT_WRITE_NEXT, S_DONE} states = S_IDLE;
                                
        localparam FSM_NUM_OF_STATES = states.num();
        logic [FSM_NUM_OF_STATES - 1:0] current_state = 0, next_state;
                            
        // Declare states
        always_ff @(posedge clk, negedge reset_n) begin : state_machine_reg
            if (!reset_n) begin
                current_state <= 0;
            end else begin
                current_state <= next_state;
            end
        end : state_machine_reg
                            
        // state cast for debug, one-hot translation, enum value can be shown in the simulation in this way
        // Hopefully, synthesizer will optimize out the "states" variable
                        
        // synthesis translate_off
        ///////////////////////////////////////////////////////////////////////
        always_comb begin : state_cast_for_debug
            for (int i = 0; i < FSM_NUM_OF_STATES; ++i) begin
                if (current_state[i]) begin
                    $cast(states, i);
                end
            end
        end : state_cast_for_debug
        ///////////////////////////////////////////////////////////////////////
        // synthesis translate_on   
                                    
        // FSM main body
        always_comb begin : state_machine_comb
                        
            next_state = 0;
            
            ctl_load_onchip_flash_address = 0;
            ctl_inc_onchip_flash_address = 0;
                    
            ctl_clear_ping_state = 0;
            ctl_clear_pong_state = 0;
            
            ctl_set_ping_free = 0;
            ctl_set_ping_busy = 0;
            ctl_set_pong_free = 0;
            ctl_set_pong_busy = 0;
        
            ctl_segment_buf_read = 0;
            ctl_clear_segment_addr_counter = 0;
            ctl_flip_active_ping0_pong1 = 0;
            ctl_init_active_ping0_pong1 = 0;
            
            done = 0;
            
            case (1'b1)
                current_state[S_IDLE] : begin
                    ctl_set_ping_free <= 1'b1;
                    ctl_set_pong_free <= 1'b1;
                    
                    ctl_load_onchip_flash_address = 1'b1;
                    ctl_init_active_ping0_pong1 = 1'b1;
                    
                    if (!buf_fill_start) begin
                        next_state[S_IDLE] = 1;
                    end else begin
                        next_state[S_DATA_AVAIL_CHECK] = 1;
                    end
                end
                
                
                current_state [S_DATA_AVAIL_CHECK] : begin
                    
                    if (((!active_ping0_pong1) && (flash_buffer_ping_state == FLASH_BUF_DONE)) ||
                            ((active_ping0_pong1) && (flash_buffer_pong_state == FLASH_BUF_DONE))) begin
                        
                        next_state [S_CHECK_WAIT_REQUEST] = 1'b1;   
                            
                    end else begin
                        next_state[S_DATA_AVAIL_CHECK] = 1;
                    end
                end
                
                current_state [S_CHECK_WAIT_REQUEST] : begin
                    
                    if (!active_ping0_pong1) begin
                        ctl_set_ping_busy = 1'b1;
                    end else begin
                        ctl_set_pong_busy = 1'b1;
                    end
                    
                    
                    if (waitrequest) begin
                        next_state [S_CHECK_WAIT_REQUEST] = 1'b1;
                    end else begin
                        next_state [S_SEGMENT_BUF_READ] = 1'b1;
                    end
                    
                end
                
                
                current_state [S_SEGMENT_BUF_READ] : begin
                    ctl_segment_buf_read = 1'b1;
                    next_state [S_WAIT_READ] = 1'b1;
                end 
                
                current_state [S_WAIT_READ] : begin
                    
                    if (!flash_buffer_enable_out) begin
                        next_state [S_WAIT_READ] = 1;
                    end else begin
                        next_state [S_FLASH_SEGMENT_WRITE_NEXT] = 1'b1; 
                    end
                    
                end
                
                current_state [S_FLASH_SEGMENT_WRITE_NEXT] : begin
                    
                    if (segment_addr_counter) begin
                        ctl_inc_onchip_flash_address = 1'b1;
                        next_state [S_CHECK_WAIT_REQUEST] = 1'b1;
                    end else if (onchip_flash_address == onchip_write_end_addr) begin
                        next_state [S_DONE] = 1'b1;
                    end else begin
                        ctl_inc_onchip_flash_address = 1'b1;
                        ctl_clear_segment_addr_counter = 1'b1;
                        ctl_flip_active_ping0_pong1 = 1'b1;
                        
                        
                        if (!active_ping0_pong1) begin
                            ctl_clear_ping_state = 1'b1;
                        end else begin
                            ctl_clear_pong_state = 1'b1;
                        end
                            
                        ctl_set_ping_free = 1'b1;
                        ctl_set_pong_free = 1'b1;
                                                
                        next_state [S_DATA_AVAIL_CHECK] = 1'b1;
                    end
                    
                end
                                
                current_state[S_DONE] : begin
                    done = 1;
                    next_state[S_IDLE] = 1'b1;
                end
                                
                default: begin
                    next_state[S_IDLE] = 1'b1;
                end
                
            endcase
                  
        end : state_machine_comb
    
    
endmodule : wb_flash_loader


`default_nettype wire
