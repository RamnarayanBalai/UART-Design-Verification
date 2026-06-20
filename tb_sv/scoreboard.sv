class scoreboard;
    mailbox #(apb_trans) apb2sb;
    mailbox #(logic [7:0]) tx_mon2sb;
    mailbox #(logic [7:0]) rx_mon2sb;
    uart_config cfg;
    
    logic [7:0] tx_expected_q[$];
    logic [7:0] rx_expected_q[$];
    
    int match_count = 0;
    int error_count = 0;
    bit dlab = 1'b0;

    // Predictor variables
    int tx_fifo_count = 0; // Max 17 (16 FIFO + 1 shift reg)
    int rx_fifo_count = 0; // Max 16 (16 FIFO)

    function new(mailbox #(apb_trans) apb2sb, mailbox #(logic [7:0]) tx_mon2sb, mailbox #(logic [7:0]) rx_mon2sb, uart_config cfg);
        this.apb2sb    = apb2sb;
        this.tx_mon2sb = tx_mon2sb;
        this.rx_mon2sb = rx_mon2sb;
        this.cfg       = cfg;
    endfunction
    
    task run();
        fork
            forever begin
                apb_trans tx;
                apb2sb.get(tx);
                if (tx.write) begin
                    if (tx.addr == 5'h0C) begin
                        dlab = tx.data[7];
                        $display("[Scoreboard] APB Write LCR: Data=%2h (DLAB=%b)", tx.data[7:0], dlab);
                    end else if (tx.addr == 5'h08) begin
                        $display("[Scoreboard] APB Write FCR: Data=%2h", tx.data[7:0]);
                        // Handle FIFO clears
                        if (tx.data[2]) begin // TX FIFO Clear
                            if (tx_expected_q.size() > 0) begin
                                logic [7:0] in_flight = tx_expected_q[0];
                                tx_expected_q.delete();
                                tx_expected_q.push_back(in_flight);
                                tx_fifo_count = 1;
                                $display("[Scoreboard] FCR TX FIFO Clear: keeping in-flight byte %2h, clearing remaining (Count: 1)", in_flight);
                            end else begin
                                tx_expected_q.delete();
                                tx_fifo_count = 0;
                                $display("[Scoreboard] FCR TX FIFO Clear: empty");
                            end
                        end
                        if (tx.data[1]) begin // RX FIFO Clear
                            rx_expected_q.delete();
                            rx_fifo_count = 0;
                            $display("[Scoreboard] FCR RX FIFO Clear: cleared all expected RX bytes");
                        end
                    end else if (tx.addr == 5'h00 && !dlab) begin
                        if (tx_fifo_count < 17) begin
                            $display("[Scoreboard] APB Write THR: Data=%2h (Count: %0d -> %0d)", tx.data[7:0], tx_fifo_count, tx_fifo_count + 1);
                            tx_expected_q.push_back(tx.data[7:0]);
                            tx_fifo_count++;
                        end else begin
                            $display("[Scoreboard] APB Write THR: Data=%2h IGNORED (FIFO Full, Count: 17/17)", tx.data[7:0]);
                        end
                    end else begin
                        $display("[Scoreboard] APB Write Reg %2h: Data=%2h (DLAB=%b)", tx.addr, tx.data[7:0], dlab);
                    end
                end else begin // APB Read
                    if (tx.addr == 5'h0C) begin
                        dlab = tx.data[7];
                        $display("[Scoreboard] APB Read LCR: Data=%2h (DLAB=%b)", tx.data[7:0], dlab);
                    end else if (tx.addr == 5'h00 && !dlab) begin
                        if (rx_expected_q.size() == 0) begin
                            if (tx.data[7:0] !== 8'h00) begin
                                $display("[Scoreboard] ERROR: APB RBR Read got %2h but rx queue empty (expected 00)!", tx.data[7:0]);
                                error_count++;
                            end else begin
                                $display("[Scoreboard] SUCCESS: APB RBR Read got 8'h00 (empty read match)");
                                match_count++;
                            end
                        end else begin
                            logic [7:0] exp = rx_expected_q.pop_front();
                            if (rx_fifo_count > 0) rx_fifo_count--;
                            if (tx.data[7:0] !== exp) begin
                                $display("[Scoreboard] ERROR: APB RBR Read got %2h, expected %2h (Count: %0d)", tx.data[7:0], exp, rx_fifo_count);
                                error_count++;
                            end else begin
                                $display("[Scoreboard] SUCCESS: APB RBR Read got %2h, matches expected (Count: %0d)", tx.data[7:0], rx_fifo_count);
                                match_count++;
                            end
                        end
                    end else if (tx.addr != 5'h14) begin // Do not log LSR read polling to avoid log flooding
                        $display("[Scoreboard] APB Read Reg %2h: Data=%2h (DLAB=%b)", tx.addr, tx.data[7:0], dlab);
                    end
                end
            end
            
            forever begin
                logic [7:0] act;
                tx_mon2sb.get(act);
                if (tx_expected_q.size() == 0) begin
                    $display("[Scoreboard] ERROR: Captured TX serial byte %2h but tx queue empty!", act);
                    error_count++;
                end else begin
                    logic [7:0] exp = tx_expected_q.pop_front();
                    if (tx_fifo_count > 0) tx_fifo_count--;
                    if (act !== exp) begin
                        $display("[Scoreboard] ERROR: Captured TX serial byte %2h, expected %2h (Count: %0d)", act, exp, tx_fifo_count);
                        error_count++;
                    end else begin
                        $display("[Scoreboard] SUCCESS: Captured TX serial byte %2h matches expected (Count: %0d)", act, tx_fifo_count);
                        match_count++;
                    end
                end
            end
            
            forever begin
                logic [7:0] act;
                rx_mon2sb.get(act);
                if (rx_fifo_count < 16) begin
                    $display("[Scoreboard] Captured RX serial byte: %2h (Count: %0d -> %0d)", act, rx_fifo_count, rx_fifo_count + 1);
                    rx_expected_q.push_back(act);
                    rx_fifo_count++;
                end else begin
                    $display("[Scoreboard] Captured RX serial byte: %2h IGNORED (FIFO Full Overrun, Count: 16/16)", act);
                end
            end
        join
    endtask
endclass
