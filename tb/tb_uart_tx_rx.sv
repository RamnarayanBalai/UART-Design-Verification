`timescale 1ns / 1ps

module tb_uart_tx_rx;

    logic clk;
    logic rst_n;

    logic [15:0] divisor;
    logic bclk;
    logic bclk_en;

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
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .err_pe(err_pe),
        .err_fe(err_fe),
        .err_bi(err_bi)
    );

    always #10 clk = ~clk;

    // Helper task to send manual 8-E-1 frame (1 start + 8 data + 1 parity + 1 stop)
    task automatic send_manual_frame(
        input logic [7:0] data,
        input logic parity_val,
        input logic stop_val
    );
        int bit_time_ns = 320 * divisor; // dynamic bit time
        force_rxd = 1;
        
        // Start bit
        rxd_force_val = 0;
        #(bit_time_ns);
        
        // Data bits (LSB first)
        for (int i = 0; i < 8; i++) begin
            rxd_force_val = data[i];
            #(bit_time_ns);
        end
        
        // Parity bit
        rxd_force_val = parity_val;
        #(bit_time_ns);
        
        // Stop bit
        rxd_force_val = stop_val;
        #(bit_time_ns);
        
        force_rxd = 0;
        #100;
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        divisor = 16'd4;
        cfg_bc = 0;
        tx_data = 0;
        tx_start = 0;
        loopback_enable = 1;
        force_rxd = 0;
        rxd_force_val = 1;

        #40;
        rst_n = 1;
        #40;

        $display("Starting UART TX/RX 8-E-1 Testbench...");
        $fflush();

        // TC1: 8-E-1 Normal Loopback
        @(posedge clk);
        tx_data = 8'hA5; // Parity of A5 (10100101) is 4 ones -> Even parity is 0
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        @(posedge rx_valid);
        #1;
        if (rx_data !== 8'hA5 || err_pe || err_fe || err_bi) begin
            $display("FAIL: TC1 (Normal loopback) - data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end else begin
            $display("PASS: TC1 (Normal loopback)");
        end
        $fflush();

        wait(tx_busy == 0);
        #100;

        // TC2: Manual Frame - Parity Error
        loopback_enable = 0;
        
        fork
            send_manual_frame(8'hA5, 1'b1, 1'b1); // Correct even parity is 0, we send 1
            @(posedge rx_valid);
        join
        #1;
        
        if (rx_data !== 8'hA5 || err_pe !== 1'b1 || err_fe !== 1'b0) begin
            $display("FAIL: TC2 (Parity Error) - data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end else begin
            $display("PASS: TC2 (Parity Error)");
        end
        $fflush();

        #100;

        // TC3: Manual Frame - Framing Error
        fork
            send_manual_frame(8'h55, 1'b0, 1'b0); // Drive stop bit low (0) instead of high (1)
            @(posedge rx_valid);
        join
        #1;
        
        if (rx_data !== 8'h55 || err_fe !== 1'b1) begin
            $display("FAIL: TC3 (Framing Error) - data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end else begin
            $display("PASS: TC3 (Framing Error)");
        end
        $fflush();

        #100;

        // TC4: Manual Frame - Break Indicator
        fork
            begin
                force_rxd = 1;
                rxd_force_val = 0;
                #(320 * divisor * 15.0); // Drive low for 15 bit periods
                force_rxd = 0;
            end
            @(posedge rx_valid);
        join
        #1;
        
        if (err_bi !== 1'b1 || err_fe !== 1'b1 || rx_data !== 8'h00) begin
            $display("FAIL: TC4 (Break Indicator) - data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end else begin
            $display("PASS: TC4 (Break Indicator)");
        end
        $fflush();

        #100;
        $display("UART TX/RX Test Done.");
        $fflush();
        $finish;
    end

endmodule
