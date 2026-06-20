class env_coverage;
    
    covergroup lcr_cg with function sample(apb_trans tx);
        wls: coverpoint tx.data[1:0] {
            bins len_5 = {2'b00};
            bins len_6 = {2'b01};
            bins len_7 = {2'b10};
            bins len_8 = {2'b11};
        }
        stb: coverpoint tx.data[2] {
            bins stop_1 = {1'b0};
            bins stop_2 = {1'b1};
        }
        pen: coverpoint tx.data[3] {
            bins par_dis = {1'b0};
            bins par_en  = {1'b1};
        }
        eps: coverpoint tx.data[4] {
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
            lcr_cg.sample(tx);
        end
    endfunction
endclass
