// =============================================================================
// Testbench: tb_fifo
// Project: UART Design & Verification
// Description: Verifies the parameterized synchronous FIFO functionality.
// =============================================================================

`timescale 1ns / 1ps

module tb_fifo;

    // Parameters
    localparam int DEPTH = 16;
    localparam int WIDTH = 8;

    // Inputs
    logic             clk;
    logic             rst_n;
    logic             clear;
    logic [WIDTH-1:0] wdata;
    logic             write;
    logic             read;

    // Outputs
    logic [WIDTH-1:0] rdata;
    logic             full;
    logic             empty;
    logic [$clog2(DEPTH):0] count;

    // Instantiate UUT
    fifo #(
        .DEPTH(DEPTH),
        .WIDTH(WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .clear(clear),
        .wdata(wdata),
        .write(write),
        .read(read),
        .rdata(rdata),
        .full(full),
        .empty(empty),
        .count(count)
    );

    // Clock generation: 100MHz (10ns period)
    always #5 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk   = 0;
        rst_n = 0;
        clear = 0;
        wdata = 0;
        write = 0;
        read  = 0;

        // Reset
        #20;
        rst_n = 1;
        #20;

        $display("----------------------------------------");
        $display("Starting FIFO Testbench");
        $display("----------------------------------------");

        // Test Case 1: Verification of Empty State on Reset
        $display("[TC1] Checking initial empty flags");
        if (!empty || full || count !== 0) begin
            $display("ERROR: TC1 Failed. empty=%b, full=%b, count=%d", empty, full, count);
        end else begin
            $display("SUCCESS: TC1 Passed.");
        end

        // Test Case 2: Fill FIFO completely
        $display("[TC2] Filling FIFO completely (16 items)");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            wdata = i + 8'hA0; // Data pattern: A0, A1, ...
            write = 1;
            #1; // Hold time delay
        end
        @(posedge clk);
        write = 0;
        #1;
        if (!full || empty || count !== DEPTH) begin
            $display("ERROR: TC2 Failed. full=%b, empty=%b, count=%d", full, empty, count);
        end else begin
            $display("SUCCESS: TC2 Passed. FIFO is full.");
        end

        // Test Case 3: Try to write to a Full FIFO (should be ignored)
        $display("[TC3] Writing to a full FIFO (should be ignored)");
        @(posedge clk);
        wdata = 8'hFF;
        write = 1;
        #1;
        @(posedge clk);
        write = 0;
        #1;
        if (count !== DEPTH) begin
            $display("ERROR: TC3 Failed. Occupancy changed on overflow write. count=%d", count);
        end else begin
            $display("SUCCESS: TC3 Passed.");
        end

        // Test Case 4: Pop all elements and verify FIFO order
        $display("[TC4] Popping all elements and verifying FIFO ordering");
        for (int i = 0; i < DEPTH; i++) begin
            if (rdata !== (i + 8'hA0)) begin
                $display("ERROR: TC4 Failed at index %0d. Expected %2h, got %2h", i, i + 8'hA0, rdata);
            end
            @(posedge clk);
            read = 1;
            #1;
        end
        @(posedge clk);
        read = 0;
        #1;
        if (!empty || full || count !== 0) begin
            $display("ERROR: TC4 Failed. empty=%b, full=%b, count=%d", empty, full, count);
        end else begin
            $display("SUCCESS: TC4 Passed. FIFO is empty and data matches.");
        end

        // Test Case 5: Synchronous Clear
        $display("[TC5] Testing Synchronous Clear");
        // Put 5 items in
        for (int i = 0; i < 5; i++) begin
            @(posedge clk);
            wdata = i;
            write = 1;
            #1;
        end
        @(posedge clk);
        write = 0;
        #1;
        $display("Occupancy before clear: %0d", count);
        @(posedge clk);
        clear = 1;
        #1;
        @(posedge clk);
        clear = 0;
        #1;
        if (!empty || count !== 0) begin
            $display("ERROR: TC5 Failed. clear failed. count=%d", count);
        end else begin
            $display("SUCCESS: TC5 Passed. FIFO cleared.");
        end

        // Test Case 6: Concurrent write and read
        $display("[TC6] Testing concurrent write and read (count should remain constant)");
        // Write 1 item first
        @(posedge clk);
        wdata = 8'h55;
        write = 1;
        #1;
        @(posedge clk);
        write = 0;
        #1;
        $display("Count after 1 write: %0d (expected 1)", count);
        
        // Assert both write and read
        @(posedge clk);
        wdata = 8'hAA;
        write = 1;
        read  = 1;
        #1;
        @(posedge clk);
        write = 0;
        read  = 0;
        #1;
        $display("Count after concurrent write/read: %0d (expected 1)", count);
        if (count !== 1) begin
            $display("ERROR: TC6 Failed. Count is %d", count);
        end else begin
            $display("SUCCESS: TC6 Passed.");
        end

        #20;
        $display("----------------------------------------");
        $display("FIFO Verification Completed!");
        $display("----------------------------------------");
        $finish;
    end

endmodule
