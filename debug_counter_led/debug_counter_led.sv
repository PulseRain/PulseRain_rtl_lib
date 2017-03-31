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
//    flashing led. 
//    It can also be used as an indication of watch dog timer. If the watch dog
// timer times out, the LED will stop flashing. In addition, if the register 
// value written is not zero, a pulse will be generate. This can serve as a way
// to verify the return value in firmware for debugging / verification purpose.
//=============================================================================

`include "common.svh"
`include "debug_counter_led.svh"

`default_nettype none

module debug_counter_led
        #(parameter REG_ADDR) (
        
    //========== INPUT ==========
    input  wire                                 clk,
    input  wire                                 reset_n,
    
    input  wire                                 stb_i,
    input  wire                                 we_i,
    
    input  wire  unsigned [DATA_WIDTH - 1 : 0]  adr_wr_i,
    input  wire  unsigned [DATA_WIDTH - 1 : 0]  adr_rd_i,
    input  wire  unsigned [DATA_WIDTH - 1 : 0]  dat_i,
    
    //========== OUTPUT ==========
    output wire  unsigned [DATA_WIDTH - 1 : 0]  dat_o,
    output wire                                 ack_o,
    
    output logic                                led,
    output logic                                non_zero_pulse,
    output logic                                dog_bite
);
    
    //=======================================================================
    // Signals
    //=======================================================================
            
    logic unsigned [26 : 0]                     flashing_counter;
    logic                                       led_internal;
    
    logic unsigned [15 : 0]                     watch_dog_counter;
    
    
    
    
    assign dat_o = SYS_VER;
    
    FASM_register #(.REG_ADDR (REG_ADDR)) FASM_register_i (.*,
            .we (stb_i & we_i),
            .adr_wr (adr_wr_i),
            .adr_rd (adr_rd_i),
            .din (dat_i),
            .data_reg ());
        
    always_comb begin
        if ((stb_i & we_i) && (adr_wr_i == REG_ADDR) && (dat_i)) begin
            non_zero_pulse = 1'b1;
        end else begin 
            non_zero_pulse = 0;
        end
    end
    
    /*always_comb begin
        if ((stb_i & we_i) && (adr_wr_i == REG_ADDR)) begin
            led = 1'b1;
        end else begin
            led = 0;
        end
        
    end
    */
    assign ack_o = stb_i;
    
    
    //=======================================================================
    // LED
    //=======================================================================
        always_ff @(posedge clk) begin
            flashing_counter <= flashing_counter + ($size(flashing_counter))'(1);
        end
        
        always_ff @(posedge clk, negedge reset_n) begin
            if (!reset_n) begin
                led_internal <= 0;
                led <= 0;
            end else begin
                led <= led_internal;
                
                led_internal <= flashing_counter[$high(flashing_counter)] & (~dog_bite);
                 
            end
                
        end
        
        always_ff @(posedge clk, negedge reset_n) begin
            if (!reset_n) begin
                watch_dog_counter <= 0;
                dog_bite <= 0;
            end else begin
                if ((stb_i & we_i) && (adr_wr_i == REG_ADDR)) begin
                    watch_dog_counter <= {dat_i, 8'hFE};
                end else if (watch_dog_counter < ((2**($high(watch_dog_counter) + 1) - 1))) begin
                    watch_dog_counter <= watch_dog_counter + ($size(watch_dog_counter))'(1);
                end 
                
                if ((stb_i & we_i) && (adr_wr_i == REG_ADDR) && (!dat_i)) begin
                    dog_bite <= 0;
                end else if (watch_dog_counter == ((2**($high(watch_dog_counter) + 1) - 1))) begin
                    dog_bite <= 1'b1;
                end
            end
            
        end
        
endmodule : debug_counter_led

`default_nettype wire
