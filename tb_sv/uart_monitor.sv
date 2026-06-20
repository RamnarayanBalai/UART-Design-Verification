class uart_monitor;
    virtual uart_interface vif;
    mailbox #(logic [7:0]) mon2sb;
    uart_config cfg;
    bit is_tx;

    function new(virtual uart_interface vif, mailbox #(logic [7:0]) mon2sb, uart_config cfg, bit is_tx);
        this.vif    = vif;
        this.mon2sb = mon2sb;
        this.cfg    = cfg;
        this.is_tx  = is_tx;
    endfunction

    task run();
        real bit_period;
        logic [7:0] data;
        forever begin
            bit_period = cfg.get_bit_period_ns();
            if (is_tx) begin
                @(negedge vif.TXD);
                #(bit_period / 2.0);
                if (vif.TXD !== 1'b0) continue;
            end else begin
                @(negedge vif.RXD);
                #(bit_period / 2.0);
                if (vif.RXD !== 1'b0) continue;
            end

            data = 0;
            for (int i = 0; i < cfg.wls; i++) begin
                #(bit_period);
                if (is_tx)
                    data[i] = vif.TXD;
                else
                    data[i] = vif.RXD;
            end

            if (cfg.pen) begin
                #(bit_period);
            end

            #(bit_period);
            mon2sb.put(data);
        end
    endtask
endclass
