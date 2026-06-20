// =============================================================================
// Testbench: tb_uart_tx_rx
// Project: UART Design & Verification
// Description: Verifies the serial transmitter and receiver engines, testing
//              various data formats, parity configurations, stop bits, and 
//              manually injecting error conditions (parity, framing, break).
// =============================================================================

`timescale 1ns / 1ps

module tb_uart_tx_rx;

    // Clock and Reset
    logic clk;
    logic rst_n;

    // Baud Rate signals
    logic [15:0] divisor;
    logic bclk;
    logic bclk_en;

    // Config signals
    logic [1:0] cfg_wls;
    logic       cfg_stb;
    logic       cfg_pen;
    logic       cfg_eps;
    logic       cfg_bc;

    // Transmitter signals
    logic [7:0] tx_data;
    logic       tx_start;
    logic       txd;
    logic       tx_busy;
    logic       tx_done;

    // Receiver signals
    logic       rxd;
    logic [7:0] rx_data;
    logic       rx_valid;
    logic       err_pe;
    logic       err_fe;
    logic       err_bi;

    // Loopback control helper
    logic loopback_enable;
    logic rxd_force_val;
    logic force_rxd;

    // Connect RXD to loopback or testbench forced value
    assign rxd = force_rxd ? rxd_force_val : (loopback_enable ? txd : 1'b1);

    // Instantiate Baud Rate Generator
    baud_rate_generator brg (
        .clk(clk),
        .rst_n(rst_n),
        .divisor(divisor),
        .bclk(bclk),
        .bclk_en(bclk_en)
    );

    // Instantiate Transmitter
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

    // Instantiate Receiver
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

    // Debug Monitor
    always @(posedge clk) begin
        if (rst_n) begin
            $display("[DEBUG] Time=%0d | TX_State=%0d txd=%b bclk_en=%b tx_busy=%b | RX_State=%0d rxd=%b rxd_sync=%b RX_bclk_cnt=%0d RX_bit_cnt=%0d rx_valid=%b", 
                     $time, tx.state, txd, bclk_en, tx_busy, rx.state, rxd, rx.rxd_sync, rx.bclk_count, rx.bit_count, rx_valid);
        end
    end

    // Clock: 50MHz (20ns period)
    always #10 clk = ~clk;

    // Task to send a serial byte manually (for error injections)
    task automatic send_manual_frame(
        input logic [7:0] data,
        input int wls_len,
        input logic parity_val,
        input logic stop_val
    );
        // Bit period is 16 BCLK ticks. With divisor=4, it is 4*16 = 64 system clock cycles (1280ns)
        int bit_time_ns = 1280; 
        
        $display("[TB] Sending manual frame: Data=8'h%2h, Parity=%b, Stop=%b", data, parity_val, stop_val);
        force_rxd = 1;
        
        // Start bit (low)
        rxd_force_val = 0;
        #(bit_time_ns);
        
        // Data bits
        for (int i = 0; i < wls_len; i++) begin
            rxd_force_val = data[i];
            #(bit_time_ns);
        end
        
        // Parity bit (if enabled, manually drive it)
        if (cfg_pen) begin
            rxd_force_val = parity_val;
            #(bit_time_ns);
        end
        
        // Stop bit
        rxd_force_val = stop_val;
        #(bit_time_ns);
        
        force_rxd = 0;
        #100;
    endtask

    initial begin
        // Init signals
        clk = 0;
        rst_n = 0;
        divisor = 16'd4; // Fast divisor for simulation speed
        cfg_wls = 2'b11; // 8-bit
        cfg_stb = 0;     // 1 stop bit
        cfg_pen = 0;     // No parity
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

        $display("----------------------------------------");
        $display("Starting UART TX/RX Testbench");
        $display("----------------------------------------");

        // Test Case 1: Standard 8-bit, No Parity Loopback
        $display("[TC1] 8-bit, No Parity Loopback");
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
            $display("ERROR: TC1 Failed. Got: data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end else begin
            $display("SUCCESS: TC1 Passed. Received 8'h%2h correctly.", rx_data);
        end
        #100;

        // Test Case 2: 7-bit, Even Parity, 2 Stop bits Loopback
        $display("[TC2] 7-bit, Even Parity, 2 Stop bits Loopback");
        cfg_wls = 2'b10; // 7 bits
        cfg_pen = 1;     // Parity enable
        cfg_eps = 1;     // Even
        cfg_stb = 1;     // 2 Stop bits (Treated as 1 stop bit by RX, but TX sends 2)
        
        @(posedge clk);
        tx_data = 8'h3F; // Binary: 011_1111 (six 1s, even parity expected = 0)
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        @(posedge rx_valid);
        #1;
        if (rx_data !== 8'h3F || err_pe || err_fe || err_bi) begin
            $display("ERROR: TC2 Failed. Got: data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end else begin
            $display("SUCCESS: TC2 Passed. Received 7-bit 8'h%2h correctly.", rx_data);
        end
        #200; // Wait for stop bits to finish in TX

        // Test Case 3: 5-bit, Odd Parity, 1.5 Stop bits Loopback
        $display("[TC3] 5-bit, Odd Parity, 1.5 Stop bits Loopback");
        cfg_wls = 2'b00; // 5 bits
        cfg_pen = 1;     // Parity
        cfg_eps = 0;     // Odd
        cfg_stb = 1;     // 1.5 stop bits for 5-bit mode
        
        @(posedge clk);
        tx_data = 8'h13; // Binary: 1_0011 (three 1s, odd parity expected = 0)
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        @(posedge rx_valid);
        #1;
        if (rx_data !== 8'h13 || err_pe || err_fe || err_bi) begin
            $display("ERROR: TC3 Failed. Got: data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end else begin
            $display("SUCCESS: TC3 Passed. Received 5-bit 8'h%2h correctly.", rx_data);
        end
        #200;

        // Test Case 4: Manual Frame - Parity Error Injection
        $display("[TC4] Manual Frame - Parity Error Injection");
        cfg_wls = 2'b11;
        cfg_pen = 1;
        cfg_eps = 1; // Even parity expected for 8'h55 (four 1s) is 0. We will inject parity = 1.
        loopback_enable = 0;
        
        // Send manual frame: data=8'h55, wls_len=8, parity_val=1 (wrong!), stop_val=1
        send_manual_frame(8'h55, 8, 1'b1, 1'b1);
        
        @(posedge rx_valid);
        #1;
        if (rx_data == 8'h55 && err_pe == 1'b1 && err_fe == 1'b0) begin
            $display("SUCCESS: TC4 Passed. Correctly detected parity error.");
        end else begin
            $display("ERROR: TC4 Failed. Got: data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end
        #100;

        // Test Case 5: Manual Frame - Framing Error Injection
        $display("[TC5] Manual Frame - Framing Error Injection");
        cfg_wls = 2'b11;
        cfg_pen = 0;
        
        // Send manual frame: data=8'hAA, wls_len=8, parity_val=0, stop_val=0 (wrong stop bit!)
        send_manual_frame(8'hAA, 8, 1'b0, 1'b0);
        
        @(posedge rx_valid);
        #1;
        if (rx_data == 8'hAA && err_fe == 1'b1) begin
            $display("SUCCESS: TC5 Passed. Correctly detected framing error.");
        end else begin
            $display("ERROR: TC5 Failed. Got: data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end
        #100;

        // Test Case 6: Manual Frame - Break Indicator Injection
        $display("[TC6] Manual Frame - Break Indicator Injection");
        // Hold RXD low for full frame time: 1 start (1.28us) + 8 data (10.24us) + 1 stop (1.28us) = 12.8us
        force_rxd = 1;
        rxd_force_val = 0;
        #(15000); // Hold low for 15us
        force_rxd = 0;
        
        @(posedge rx_valid);
        #1;
        if (err_bi == 1'b1 && err_fe == 1'b1 && rx_data == 8'h00) begin
            $display("SUCCESS: TC6 Passed. Correctly detected Break condition.");
        end else begin
            $display("ERROR: TC6 Failed. Got: data=8'h%2h, pe=%b, fe=%b, bi=%b", rx_data, err_pe, err_fe, err_bi);
        end
        #100;

        $display("----------------------------------------");
        $display("UART TX/RX Verification Completed!");
        $display("----------------------------------------");
        $finish;
    end

endmodule
