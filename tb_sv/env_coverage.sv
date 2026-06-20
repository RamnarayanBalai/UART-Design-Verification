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

    covergroup baud_rate_cg with function sample(logic [15:0] divisor);
        divisor_val: coverpoint divisor {
            bins low_div   = {[4:10]};
            bins mid_div   = {[11:30]};
            bins high_div  = {[31:64]};
        }
    endgroup

    covergroup tx_data_cg with function sample(logic [7:0] data);
        data_val: coverpoint data {
            bins zeros      = {8'h00};
            bins ones       = {8'hFF};
            bins walking_0s = {8'hFE, 8'hFD, 8'hFB, 8'hF7, 8'hEF, 8'hDF, 8'hBF, 8'h7F};
            bins walking_1s = {8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80};
            bins others     = default;
        }
    endgroup

    covergroup lsr_status_cg with function sample(logic [7:0] lsr_val);
        dr:   coverpoint lsr_val[0] { bins zero = {1'b0}; bins one = {1'b1}; }
        oe:   coverpoint lsr_val[1] { bins zero = {1'b0}; bins one = {1'b1}; }
        pe:   coverpoint lsr_val[2] { bins zero = {1'b0}; bins one = {1'b1}; }
        fe:   coverpoint lsr_val[3] { bins zero = {1'b0}; bins one = {1'b1}; }
        bi:   coverpoint lsr_val[4] { bins zero = {1'b0}; bins one = {1'b1}; }
        thre: coverpoint lsr_val[5] { bins zero = {1'b0}; bins one = {1'b1}; }
        temt: coverpoint lsr_val[6] { bins zero = {1'b0}; bins one = {1'b1}; }
    endgroup

    function new();
        reg_access_cg = new();
        baud_rate_cg  = new();
        tx_data_cg    = new();
        lsr_status_cg = new();
    endfunction

    function void sample(apb_trans tx);
        reg_access_cg.sample(tx);
        
        // Sample data values on THR writes
        if (tx.write && tx.addr == 5'h00) begin
            tx_data_cg.sample(tx.data[7:0]);
        end
        
        // Sample LSR register status values on reads
        if (!tx.write && tx.addr == 5'h14) begin
            lsr_status_cg.sample(tx.data[7:0]);
        end
    endfunction

    function void sample_divisor(logic [15:0] divisor);
        baud_rate_cg.sample(divisor);
    endfunction
endclass
