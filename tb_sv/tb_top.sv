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
        PCLK    = 0;
        PRESETn = 0;
        
        #40;
        PRESETn = 1;
        #40;

        $display("[TB TOP] Instantiating and initializing OOP Env...");
        env_inst = new(apb_if, uart_if);

        // Configure divisor and line control on DUT
        apb_write(5'h0C, 8'h80); // DLAB = 1
        apb_write(5'h00, 8'h04); // DLL = 4
        apb_write(5'h04, 8'h00); // DLH = 0
        apb_write(5'h0C, 8'h03); // DLAB = 0, word_length = 8, stop = 1, parity = none
        
        // Sync configuration class settings
        env_inst.cfg.divisor = 4;
        env_inst.cfg.wls     = 8;
        env_inst.cfg.pen     = 0;
        env_inst.cfg.stb     = 1;

        $display("[TB TOP] Starting randomized loopback test run...");
        env_inst.run(30);

        #100;
        $display("[TB TOP] Test Finished.");
        $finish;
    end

    // APB Write Helper Task
    task automatic apb_write(input logic [4:0] addr, input logic [7:0] data);
        @(posedge PCLK);
        apb_if.PADDR   = addr;
        apb_if.PWRITE  = 1;
        apb_if.PSEL    = 1;
        apb_if.PWDATA  = {24'd0, data};
        @(posedge PCLK);
        apb_if.PENABLE = 1;
        @(posedge PCLK);
        apb_if.PSEL    = 0;
        apb_if.PENABLE = 0;
    endtask

endmodule
