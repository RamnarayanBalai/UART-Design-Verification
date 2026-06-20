class env;
    virtual apb_interface  vif;
    virtual uart_interface v_uart;
    
    mailbox #(apb_trans) gen2drv;
    mailbox #(apb_trans) apb2sb;
    mailbox #(logic [7:0]) tx_mon2sb;
    mailbox #(logic [7:0]) rx_mon2sb;
    
    event drv_done;
    
    uart_config cfg;
    generator  gen;
    driver     drv;
    apb_monitor mon_apb;
    uart_monitor mon_uart_tx;
    uart_monitor mon_uart_rx;
    scoreboard sb;
    env_coverage cov;

    function new(virtual apb_interface vif, virtual uart_interface v_uart);
        this.vif    = vif;
        this.v_uart = v_uart;
        
        gen2drv   = new();
        apb2sb    = new();
        tx_mon2sb = new();
        rx_mon2sb = new();
        
        cfg         = new();
        gen         = new(gen2drv, drv_done, cfg);
        drv         = new(vif, gen2drv, drv_done);
        cov         = new();
        mon_apb     = new(vif, apb2sb, cov);
        mon_uart_tx = new(v_uart, tx_mon2sb, cfg, 1'b1);
        mon_uart_rx = new(v_uart, rx_mon2sb, cfg, 1'b0);
        sb          = new(apb2sb, tx_mon2sb, rx_mon2sb);
    endfunction

    task run(int num_tx);
        fork
            drv.run();
            mon_apb.run();
            mon_uart_tx.run();
            mon_uart_rx.run();
            sb.run();
        join_none
        
        gen.run(num_tx);
        
        // Wait for final frame transmission to complete
        #(cfg.get_bit_period_ns() * 20.0);
        
        $display("[Env] Test run completed. Matches=%0d, Errors=%0d", sb.match_count, sb.error_count);
    endtask
endclass
