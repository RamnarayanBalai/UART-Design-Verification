class driver;
    virtual apb_interface vif;
    mailbox #(apb_trans) gen2drv;
    event drv_done;

    function new(virtual apb_interface vif, mailbox #(apb_trans) gen2drv, event drv_done);
        this.vif      = vif;
        this.gen2drv  = gen2drv;
        this.drv_done = drv_done;
    endfunction

    task run();
        apb_trans tx;
        forever begin
            gen2drv.get(tx);
            drive_trans(tx);
            ->drv_done;
        end
    endtask

    task drive_trans(apb_trans tx);
        @(vif.cb_driver);
        vif.cb_driver.PADDR   <= tx.addr;
        vif.cb_driver.PWRITE  <= tx.write;
        vif.cb_driver.PSEL    <= 1'b1;
        vif.cb_driver.PWDATA  <= tx.data;
        vif.cb_driver.PENABLE <= 1'b0;
        @(vif.cb_driver);
        vif.cb_driver.PENABLE <= 1'b1;
        @(vif.cb_driver);
        if (!tx.write) begin
            tx.data = vif.cb_driver.PRDATA;
        end
        vif.cb_driver.PSEL    <= 1'b0;
        vif.cb_driver.PENABLE <= 1'b0;
    endtask
endclass
