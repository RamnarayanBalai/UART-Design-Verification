class env_coverage;
    
    covergroup reg_access_cg with function sample(apb_trans tx);
        addr: coverpoint tx.addr {
            bins thr_rbr = {5'h00};
            bins dlh     = {5'h04};
            bins fcr     = {5'h08};
            bins lcr     = {5'h0C};
            bins lsr     = {5'h14};
            bins scr     = {5'h1C};
        }
        write: coverpoint tx.write {
            bins wr = {1'b1};
            bins rd = {1'b0};
        }
        rw_cross: cross addr, write;
    endgroup

    function new();
        reg_access_cg = new();
    endfunction

    function void sample(apb_trans tx);
        reg_access_cg.sample(tx);
    endfunction
endclass
