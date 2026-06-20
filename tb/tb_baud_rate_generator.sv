// =============================================================================
// Testbench: tb_baud_rate_generator
// Project: UART Design & Verification
// Description: Verifies BCLK and bclk_en generation for various divisor values.
// =============================================================================

`timescale 1ns / 1ps

module tb_baud_rate_generator;

    // Inputs
    logic clk;
    logic rst_n;
    logic [15:0] divisor;

    // Outputs
    logic bclk;
    logic bclk_en;

    // Instantiate the Unit Under Test (UUT)
    baud_rate_generator uut (
        .clk(clk),
        .rst_n(rst_n),
        .divisor(divisor),
        .bclk(bclk),
        .bclk_en(bclk_en)
    );

    // Clock generation: 100MHz (10ns period)
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        time t1, t2;
        // Initialize Inputs
        clk = 0;
        rst_n = 0;
        divisor = 0;

        // Reset system
        #20;
        rst_n = 1;
        #20;

        // Test Case 1: Divisor = 0 (Unprogrammed state)
        // BCLK should remain constant high, bclk_en should remain low.
        $display("[TC1] Testing Divisor = 0");
        divisor = 16'd0;
        #100;
        if (bclk !== 1'b1 || bclk_en !== 1'b0) begin
            $display("ERROR: TC1 Failed. bclk=%b, bclk_en=%b", bclk, bclk_en);
        end else begin
            $display("SUCCESS: TC1 Passed.");
        end

        // Test Case 2: Divisor = 1 (Divide-by-1)
        // bclk_en should toggle high every cycle.
        $display("[TC2] Testing Divisor = 1");
        divisor = 16'd1;
        #50;
        // Verify multiple cycles
        repeat (10) begin
            @(posedge clk);
            #1;
            if (bclk_en !== 1'b1) $display("ERROR: TC2 Failed. bclk_en=%b", bclk_en);
        end
        $display("SUCCESS: TC2 Passed.");

        // Test Case 3: Divisor = 4 (Divide-by-4)
        // bclk_en should be high once every 4 clk periods.
        // bclk should toggle with a period of 4 clk cycles (2 cycles high, 2 cycles low).
        $display("[TC3] Testing Divisor = 4");
        divisor = 16'd4;
        #10; // wait for transition
        @(posedge bclk_en);
        // Measure time to next bclk_en pulse
        t1 = $time;
        @(posedge bclk_en);
        t2 = $time;
        if (t2 - t1 !== 40) begin
            $display("ERROR: TC3 Failed. Measured period = %0d ns (expected 40 ns)", t2 - t1);
        end else begin
            $display("SUCCESS: TC3 Passed. Period = %0d ns", t2 - t1);
        end

        // Test Case 4: Divisor = 13 (Odd divisor test)
        // bclk_en period should be 13 clk cycles (130 ns)
        $display("[TC4] Testing Divisor = 13");
        divisor = 16'd13;
        #10;
        @(posedge bclk_en);
        t1 = $time;
        @(posedge bclk_en);
        t2 = $time;
        if (t2 - t1 !== 130) begin
            $display("ERROR: TC4 Failed. Measured period = %0d ns (expected 130 ns)", t2 - t1);
        end else begin
            $display("SUCCESS: TC4 Passed. Period = %0d ns", t2 - t1);
        end

        $display("Baud Rate Generator Verification Completed!");
        $finish;
    end

endmodule
