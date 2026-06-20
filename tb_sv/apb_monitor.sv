class apb_monitor;
    virtual apb_interface vif;
    mailbox #(apb_trans) apb2sb;
    env_coverage cov;

    function new(virtual apb_interface vif, mailbox #(apb_trans) apb2sb, env_coverage cov = null);
        this.vif    = vif;
        this.apb2sb = apb2sb;
        this.cov    = cov;
    endfunction

    task run();
        forever begin
            @(vif.cb_monitor);
            if (vif.cb_monitor.PSEL && vif.cb_monitor.PENABLE && vif.cb_monitor.PREADY) begin
                apb_trans tx = new();
                tx.addr  = vif.cb_monitor.PADDR;
                tx.write = vif.cb_monitor.PWRITE;
                if (tx.write)
                    tx.data = vif.cb_monitor.PWDATA;
                else
                    tx.data = vif.cb_monitor.PRDATA;
                
                if (cov != null) cov.sample(tx);
                apb2sb.put(tx);
            end
        end
    endtask
endclass
