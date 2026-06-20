`timescale 1ns / 1ps

module tb_fifo;

    localparam int DEPTH = 16;
    localparam int WIDTH = 8;

    logic             clk;
    logic             rst_n;
    logic             clear;
    logic [WIDTH-1:0] wdata;
    logic             write;
    logic             read;

    logic [WIDTH-1:0] rdata;
    logic             full;
    logic             empty;
    logic [$clog2(DEPTH):0] count;

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

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        rst_n = 0;
        clear = 0;
        wdata = 0;
        write = 0;
        read  = 0;

        #20;
        rst_n = 1;
        #20;

        if (!empty || full || count !== 0) begin
            $display("FAIL: TC1 - empty=%b, full=%b, count=%d", empty, full, count);
        end

        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            wdata = i + 8'hA0;
            write = 1;
            #1;
        end
        @(posedge clk);
        write = 0;
        #1;
        if (!full || empty || count !== DEPTH) begin
            $display("FAIL: TC2 - full=%b, empty=%b, count=%d", full, empty, count);
        end

        @(posedge clk);
        wdata = 8'hFF;
        write = 1;
        #1;
        @(posedge clk);
        write = 0;
        #1;
        if (count !== DEPTH) begin
            $display("FAIL: TC3 - overflow write changed count. count=%d", count);
        end

        for (int i = 0; i < DEPTH; i++) begin
            if (rdata !== (i + 8'hA0)) begin
                $display("FAIL: TC4 at index %0d. Expected %2h, got %2h", i, i + 8'hA0, rdata);
            end
            @(posedge clk);
            read = 1;
            #1;
        end
        @(posedge clk);
        read = 0;
        #1;
        if (!empty || full || count !== 0) begin
            $display("FAIL: TC4 - empty state check. empty=%b, full=%b, count=%d", empty, full, count);
        end

        for (int i = 0; i < 5; i++) begin
            @(posedge clk);
            wdata = i;
            write = 1;
            #1;
        end
        @(posedge clk);
        write = 0;
        #1;
        @(posedge clk);
        clear = 1;
        #1;
        @(posedge clk);
        clear = 0;
        #1;
        if (!empty || count !== 0) begin
            $display("FAIL: TC5 - clear failed. count=%d", count);
        end

        @(posedge clk);
        wdata = 8'h55;
        write = 1;
        #1;
        @(posedge clk);
        write = 0;
        #1;
        
        @(posedge clk);
        wdata = 8'hAA;
        write = 1;
        read  = 1;
        #1;
        @(posedge clk);
        write = 0;
        read  = 0;
        #1;
        if (count !== 1) begin
            $display("FAIL: TC6 - concurrent count mismatch. count=%d", count);
        end

        #20;
        $display("FIFO Test Done.");
        $finish;
    end

endmodule
