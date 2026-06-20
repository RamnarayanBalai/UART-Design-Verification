`timescale 1ns / 1ps

module tb_uart_tx_rx;

    logic clk;
    logic rst_n;

    logic [15:0] divisor;
    logic bclk;
    logic bclk_en;

    logic [1:0] cfg_wls;
    logic       cfg_stb;
    logic       cfg_pen;
    logic       cfg_eps;
    logic       cfg_bc;

    logic [7:0] tx_data;
    logic       tx_start;
    logic       txd;
    logic       tx_busy;
    logic       tx_done;

    logic       rxd;
    logic [7:0] rx_data;
    logic       rx_valid;
    logic       err_pe;
    logic       err_fe;
    logic       err_bi;

    logic loopback_enable;
    logic rxd_force_val;
    logic force_rxd;

    assign rxd = force_rxd ? rxd_force_val : (loopback_enable ? txd : 1'b1);

    baud_rate_generator brg (
        .clk(clk),
        .rst_n(rst_n),
        .divisor(divisor),
        .bclk(bclk),
        .bclk_en(bclk_en)
    );

    uart_tx tx (
        .clk(clk),
        .rst_n(rst_n),
        .bclk_en(bclk_en),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .cfg_wls(cfg_wls),
        .cfg_stb(cfg_stb),
        .cfg_pen(cfg_pen),
        .cfg_eps(cfg_eps),
        .cfg_bc(cfg_bc),
        .txd(txd),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );

    uart_rx rx (
        .clk(clk),
        .rst_n(rst_n),
        .bclk_en(bclk_en),
        .rxd(rxd),
        .cfg_wls(cfg_wls),
        .cfg_pen(cfg_pen),
        .cfg_eps(cfg_eps),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .err_pe(err_pe),
        .err_fe(err_fe),
        .err_bi(err_bi)
    );

    always #10 clk = ~clk;

    task automatic send_manual_frame(
        input logic [7:0] data,
        input int wls_len,
        input logic parity_val,
        input logic stop_val
    );
        int bit_time_ns = 1280; 
        force_rxd = 1;
        
        rxd_force_val = 0;
        #(bit_time_ns);
        
        for (int i = 0; i < wls_len; i++) begin
            rxd_force_val = data[i];
            #(bit_time_ns);
        end
        
        if (cfg_pen) begin
            rxd_force_val = parity_val;
            #(bit_time_ns);
        end
        
        rxd_force_val = stop_val;
        #(bit_time_ns);
        
        force_rxd = 0;
        #100;
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        divisor = 16'd4;
        cfg_wls = 2'b11;
        cfg_stb = 0;
        cfg_pen = 0;
        cfg_eps = 0;
        cfg_bc = 0;
        tx_data = 0;
        tx_start = 0;
        loopback_enable = 1;
        force_rxd = 0;
        rxd_force_val = 1;

        #40;
        rst_n = 1;
        #40;

        $display("Starting UART TX/RX Testbench...");
        $fflush();

        // TC1: 8-bit, No Parity Loopback
        cfg_wls = 2'b11;
        cfg_pen = 0;
        cfg_stb = 0;
        
        @(posedge clk);
        tx_data = 8'hA5;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        @(posedge rx_valid);
        #1;
        if (rx_data !== 8'hA5 || err_pe || err_fe || err_bi) begin
            $display("FAIL: TC1 - data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end else begin
            $display("PASS: TC1");
        end
        $fflush();

        wait(tx_busy == 0);
        #100;

        // TC2: 7-bit, Even Parity, 2 Stop bits Loopback
        cfg_wls = 2'b10;
        cfg_pen = 1;
        cfg_eps = 1;
        cfg_stb = 1;
        
        @(posedge clk);
        tx_data = 8'h3F;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        @(posedge rx_valid);
        #1;
        if (rx_data !== 8'h3F || err_pe || err_fe || err_bi) begin
            $display("FAIL: TC2 - data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end else begin
            $display("PASS: TC2");
        end
        $fflush();

        wait(tx_busy == 0);
        #100;

        // TC3: 5-bit, Odd Parity, 1.5 Stop bits Loopback
        cfg_wls = 2'b00;
        cfg_pen = 1;
        cfg_eps = 0;
        cfg_stb = 1;
        
        @(posedge clk);
        tx_data = 8'h13;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        @(posedge rx_valid);
        #1;
        if (rx_data !== 8'h13 || err_pe || err_fe || err_bi) begin
            $display("FAIL: TC3 - data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end else begin
            $display("PASS: TC3");
        end
        $fflush();

        wait(tx_busy == 0);
        #100;

        // TC4: Manual Frame - Parity Error
        cfg_wls = 2'b11;
        cfg_pen = 1;
        cfg_eps = 1;
        loopback_enable = 0;
        
        fork
            send_manual_frame(8'h55, 8, 1'b1, 1'b1);
            @(posedge rx_valid);
        join
        #1;
        
        if (rx_data !== 8'h55 || err_pe !== 1'b1 || err_fe !== 1'b0) begin
            $display("FAIL: TC4 - data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end else begin
            $display("PASS: TC4");
        end
        $fflush();

        wait(tx_busy == 0);
        #100;

        // TC5: Manual Frame - Framing Error
        cfg_wls = 2'b11;
        cfg_pen = 0;
        
        fork
            send_manual_frame(8'hAA, 8, 1'b0, 1'b0);
            @(posedge rx_valid);
        join
        #1;
        
        if (rx_data !== 8'hAA || err_fe !== 1'b1) begin
            $display("FAIL: TC5 - data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end else begin
            $display("PASS: TC5");
        end
        $fflush();

        wait(tx_busy == 0);
        #100;

        // TC6: Manual Frame - Break Indicator
        fork
            begin
                force_rxd = 1;
                rxd_force_val = 0;
                #(15000);
                force_rxd = 0;
            end
            @(posedge rx_valid);
        join
        #1;
        
        if (err_bi !== 1'b1 || err_fe !== 1'b1 || rx_data !== 8'h00) begin
            $display("FAIL: TC6 - data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end else begin
            $display("PASS: TC6");
        end
        $fflush();

        #100;
        $display("UART TX/RX Test Done.");
        $fflush();
        $finish;
    end

endmodule
