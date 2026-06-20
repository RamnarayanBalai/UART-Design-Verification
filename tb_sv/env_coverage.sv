class env_coverage;
    apb_trans cov_tx;
    
    covergroup lcr_cg;
        wls: coverpoint cov_tx.data[1:0] {
            bins len_5 = {2'b00};
            bins len_6 = {2'b01};
            bins len_7 = {2'b10};
            bins len_8 = {2'b11};
        }
        stb: coverpoint cov_tx.data[2] {
            bins stop_1 = {1'b0};
            bins stop_2 = {1'b1};
        }
        pen: coverpoint cov_tx.data[3] {
            bins par_dis = {1'b0};
            bins par_en  = {1'b1};
        }
        eps: coverpoint cov_tx.data[4] {
            bins par_odd  = {1'b0};
            bins par_even = {1'b1};
        }
        cross wls, stb, pen, eps;
    endgroup

    function new();
        lcr_cg = new();
    endfunction

    function void sample(apb_trans tx);
        if (tx.write && tx.addr == 5'h0C) begin
            this.cov_tx = tx;
            lcr_cg.sample();
        end
    endfunction
endclass
