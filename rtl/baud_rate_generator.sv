// =============================================================================
// Module: baud_rate_generator
// Project: UART Design & Verification
// Description: Divides the input clock by a 16-bit divisor to generate a 
//              Baud Clock (BCLK) running at 16x the desired baud rate.
//              Outputs both a toggling BCLK clock and a clock enable pulse (bclk_en).
// =============================================================================

`timescale 1ns / 1ps

module baud_rate_generator (
    input  logic        clk,      // System clock / Input clock
    input  logic        rst_n,    // Active-low asynchronous reset
    input  logic [15:0] divisor,  // 16-bit divisor from DLL and DLH
    output logic        bclk,     // Toggling baud rate clock (16x baud rate)
    output logic        bclk_en   // Clock enable pulse (high for 1 clock cycle)
);

    logic [15:0] counter;
    logic [15:0] half_divisor;

    // Calculate the transition point for ~50% duty cycle
    assign half_divisor = divisor >> 1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter      <= 16'd0;
            bclk         <= 1'b1;
            bclk_en      <= 1'b0;
        end else begin
            if (divisor == 16'd0) begin
                // If divisor is not programmed, BCLK stays at logic 1 (inactive)
                counter  <= 16'd0;
                bclk     <= 1'b1;
                bclk_en  <= 1'b0;
            end else if (divisor == 16'd1) begin
                // Bypassed (divide-by-1): bclk_en is high every cycle, bclk toggles
                counter  <= 16'd0;
                bclk     <= ~bclk;
                bclk_en  <= 1'b1;
            end else begin
                if (counter >= divisor - 16'd1) begin
                    counter  <= 16'd0;
                    bclk_en  <= 1'b1;
                    bclk     <= 1'b1;
                end else begin
                    counter  <= counter + 16'd1;
                    bclk_en  <= 1'b0;
                    
                    // Toggle the output clock to low half-way through the period
                    if (counter == half_divisor - 16'd1) begin
                        bclk <= 1'b0;
                    end
                end
            end
        end
    end

endmodule
