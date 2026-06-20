`timescale 1ns / 1ps

module tb_baud_rate_generator;

    logic clk;
    logic rst_n;
    logic [15:0] divisor;
    logic bclk;
    logic bclk_en;

    baud_rate_generator uut (
        .clk(clk),
        .rst_n(rst_n),
        .divisor(divisor),
        .bclk(bclk),
        .bclk_en(bclk_en)
    );

    always #5 clk = ~clk;

    initial begin
        time t1, t2;
        clk = 0;
        rst_n = 0;
        divisor = 0;

        #20;
        rst_n = 1;
        #20;

        divisor = 16'd0;
        #100;
        if (bclk !== 1'b1 || bclk_en !== 1'b0) begin
            $display("FAIL: Divisor 0 - bclk=%b, bclk_en=%b", bclk, bclk_en);
        end

        divisor = 16'd1;
        #50;
        repeat (10) begin
            @(posedge clk);
            #1;
            if (bclk_en !== 1'b1) $display("FAIL: Divisor 1 - bclk_en=%b", bclk_en);
        end

        divisor = 16'd4;
        #10;
        @(posedge bclk_en);
        t1 = $time;
        @(posedge bclk_en);
        t2 = $time;
        if (t2 - t1 !== 40) begin
            $display("FAIL: Divisor 4 - Period = %0d ns", t2 - t1);
        end

        divisor = 16'd13;
        #10;
        @(posedge bclk_en);
        t1 = $time;
        @(posedge bclk_en);
        t2 = $time;
        if (t2 - t1 !== 130) begin
            $display("FAIL: Divisor 13 - Period = %0d ns", t2 - t1);
        end

        $display("Baud Rate Generator Test Done.");
        $finish;
    end

endmodule
