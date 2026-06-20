class generator;
    mailbox #(apb_trans) gen2drv;
    event drv_done;
    uart_config cfg;
    
    function new(mailbox #(apb_trans) gen2drv, event drv_done, uart_config cfg);
        this.gen2drv  = gen2drv;
        this.drv_done = drv_done;
        this.cfg      = cfg;
    endfunction

    task run(int num_tx);
        apb_trans tx;
        for (int i = 0; i < num_tx; i++) begin
            // Write THR
            tx = new();
            tx.addr  = 5'h00;
            tx.write = 1'b1;
            tx.data  = $urandom_range(8'h00, 8'hFF);
            gen2drv.put(tx);
            @drv_done;

            // Wait for serial loopback transmission to complete
            #(cfg.get_bit_period_ns() * 12.0);

            // Read RBR
            tx = new();
            tx.addr  = 5'h00;
            tx.write = 1'b0;
            gen2drv.put(tx);
            @drv_done;
        end
    endtask
endclass
