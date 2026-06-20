class scoreboard;
    mailbox #(apb_trans) apb2sb;
    mailbox #(logic [7:0]) tx_mon2sb;
    mailbox #(logic [7:0]) rx_mon2sb;
    
    logic [7:0] tx_expected_q[$];
    logic [7:0] rx_expected_q[$];
    
    int match_count = 0;
    int error_count = 0;

    function new(mailbox #(apb_trans) apb2sb, mailbox #(logic [7:0]) tx_mon2sb, mailbox #(logic [7:0]) rx_mon2sb);
        this.apb2sb    = apb2sb;
        this.tx_mon2sb = tx_mon2sb;
        this.rx_mon2sb = rx_mon2sb;
    endfunction
    
    task run();
        fork
            forever begin
                apb_trans tx;
                apb2sb.get(tx);
                if (tx.write && tx.addr == 5'h00) begin
                    tx_expected_q.push_back(tx.data[7:0]);
                end
                if (!tx.write && tx.addr == 5'h00) begin
                    if (rx_expected_q.size() == 0) begin
                        $display("[Scoreboard] ERROR: Read RBR but rx queue empty!");
                        error_count++;
                    end else begin
                        logic [7:0] exp = rx_expected_q.pop_front();
                        if (tx.data[7:0] !== exp) begin
                            $display("[Scoreboard] ERROR: Read got %2h, expected %2h", tx.data[7:0], exp);
                            error_count++;
                        end else begin
                            match_count++;
                        end
                    end
                end
            end
            
            forever begin
                logic [7:0] act;
                tx_mon2sb.get(act);
                if (tx_expected_q.size() == 0) begin
                    $display("[Scoreboard] ERROR: Captured TX %2h but tx queue empty!", act);
                    error_count++;
                end else begin
                    logic [7:0] exp = tx_expected_q.pop_front();
                    if (act !== exp) begin
                        $display("[Scoreboard] ERROR: Captured TX got %2h, expected %2h", act, exp);
                        error_count++;
                    end else begin
                        match_count++;
                    end
                end
            end
            
            forever begin
                logic [7:0] act;
                rx_mon2sb.get(act);
                rx_expected_q.push_back(act);
            end
        join
    endtask
endclass
