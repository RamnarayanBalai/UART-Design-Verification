// =============================================================================
// Module: fifo
// Project: UART Design & Verification
// Description: Parameterized synchronous FIFO memory with First-Word Fall-Through
//              (FWFT) read semantics. Used for TX/RX buffering.
// =============================================================================

`timescale 1ns / 1ps

module fifo #(
    parameter int DEPTH = 16,
    parameter int WIDTH = 8
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             clear,    // Synchronous clear (resets pointers/counters)
    input  logic [WIDTH-1:0] wdata,    // Write data input
    input  logic             write,    // Write enable
    input  logic             read,     // Read enable
    output logic [WIDTH-1:0] rdata,    // Read data output (FWFT)
    output logic             full,     // FIFO full flag
    output logic             empty,    // FIFO empty flag
    output logic [$clog2(DEPTH):0] count // Current occupancy count
);

    // Memory array
    logic [WIDTH-1:0] mem [DEPTH-1:0];

    // Read and Write pointers
    logic [$clog2(DEPTH)-1:0] wptr;
    logic [$clog2(DEPTH)-1:0] rptr;

    // Output flags
    assign empty = (count == '0);
    assign full  = (count == DEPTH[31:0]); // Explicit width matching

    // First-Word Fall-Through read data
    // If empty, output 0; otherwise, output memory contents at read pointer.
    assign rdata = empty ? '0 : mem[rptr];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr  <= '0;
            rptr  <= '0;
            count <= '0;
        end else begin
            if (clear) begin
                wptr  <= '0;
                rptr  <= '0;
                count <= '0;
            end else begin
                // Dual-port write operation
                if (write && !full) begin
                    mem[wptr] <= wdata;
                    wptr      <= wptr + 1'b1;
                end

                // Dual-port read operation
                if (read && !empty) begin
                    rptr      <= rptr + 1'b1;
                end

                // Synchronous occupancy count update
                case ({write && !full, read && !empty})
                    2'b10: count <= count + 1'b1;
                    2'b01: count <= count - 1'b1;
                    default: count <= count; // Remains the same on concurrent push/pop
                endcase
            end
        end
    end

endmodule
