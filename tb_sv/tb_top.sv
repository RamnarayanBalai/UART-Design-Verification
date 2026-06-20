`timescale 1ns / 1ps

module tb_top;

    import tb_pkg::*;

    logic PCLK;
    logic PRESETn;

    // Clock Generation (50MHz)
    always #10 PCLK = ~PCLK;

    // Interfaces
    apb_interface  apb_if(PCLK, PRESETn);
    uart_interface uart_if();

    // Serial loopback connection
    assign uart_if.RXD = uart_if.TXD;

    // DUT Instantiation
    apb_uart dut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PADDR(apb_if.PADDR),
        .PSEL(apb_if.PSEL),
        .PENABLE(apb_if.PENABLE),
        .PWRITE(apb_if.PWRITE),
        .PWDATA(apb_if.PWDATA),
        .PRDATA(apb_if.PRDATA),
        .PREADY(apb_if.PREADY),
        .PSLVERR(apb_if.PSLVERR),
        .TXD(uart_if.TXD),
        .RXD(uart_if.RXD)
    );

    env env_inst;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
        PCLK    = 0;
        PRESETn = 0;
        
        #40;
        PRESETn = 1;
        #40;

        $display("[TB TOP] Instantiating and initializing OOP Env...");
        env_inst = new(apb_if, uart_if);

        // Randomize the config class dynamically
        if (!env_inst.cfg.randomize()) begin
            $error("[TB TOP] Configuration randomization failed!");
        end

        $display("[TB TOP] Randomized Config: Divisor=%0d, WordLength=%0d, ParityEnable=%0d, EvenParity=%0d, StopBits=%0d",
                 env_inst.cfg.divisor, env_inst.cfg.wls, env_inst.cfg.pen, env_inst.cfg.eps, env_inst.cfg.stb);

        // Map randomized config values to register fields and program DUT via APB
        begin
            logic [7:0] lcr_val;
            lcr_val = 8'h00;
            lcr_val[1:0] = env_inst.cfg.wls - 5;
            lcr_val[2]   = (env_inst.cfg.stb == 2);
            lcr_val[3]   = env_inst.cfg.pen;
            lcr_val[4]   = env_inst.cfg.eps;

            // Write DLL/DLH (DLAB = 1)
            apb_write(5'h0C, 8'h80); // Set DLAB = 1
            apb_write(5'h00, env_inst.cfg.divisor[7:0]); // DLL LSB
            apb_write(5'h04, env_inst.cfg.divisor[15:8]); // DLH MSB
            
            // Write LCR settings (DLAB = 0)
            apb_write(5'h0C, lcr_val); 
        end

        $display("[TB TOP] Starting randomized loopback test run...");
        env_inst.run(30);

        #100;
        $display("[TB TOP] Test Finished.");
        $finish;
    end

    // APB Write Helper Task
    task automatic apb_write(input logic [4:0] addr, input logic [7:0] data);
        @(apb_if.cb_driver);
        apb_if.cb_driver.PADDR   <= addr;
        apb_if.cb_driver.PWRITE  <= 1'b1;
        apb_if.cb_driver.PSEL    <= 1'b1;
        apb_if.cb_driver.PWDATA  <= {24'd0, data};
        apb_if.cb_driver.PENABLE <= 1'b0;
        @(apb_if.cb_driver);
        apb_if.cb_driver.PENABLE <= 1'b1;
        @(apb_if.cb_driver);
        apb_if.cb_driver.PSEL    <= 1'b0;
        apb_if.cb_driver.PENABLE <= 1'b0;
    endtask

`ifndef __ICARUS__
    // Bind assertion module to all uart_tx instances
    bind uart_tx uart_tx_sva tx_sva_inst (
        .clk(clk),
        .rst_n(rst_n),
        .txd(txd),
        .state(state)
    );
`endif

endmodule
