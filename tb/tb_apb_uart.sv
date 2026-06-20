`timescale 1ns / 1ps

module tb_apb_uart;

    logic        PCLK;
    logic        PRESETn;
    logic [4:0]  PADDR;
    logic        PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [31:0] PWDATA;
    logic [31:0] PRDATA;
    logic        PREADY;
    logic        PSLVERR;
    logic        TXD;
    logic        RXD;

    apb_uart uut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR),
        .TXD(TXD),
        .RXD(RXD)
    );

    assign RXD = TXD;

    always #10 PCLK = ~PCLK;

    always @(posedge PCLK) begin
        if (PRESETn) begin
            $display("[DEBUG] Time=%0d | PADDR=%2h PWRITE=%b PSEL=%b PENABLE=%b PWDATA=%2h PRDATA=%2h | TX_State=%0d RX_State=%0d TXD=%b RXD=%b LSR=%2h DR=%b | rx_count=%0d tx_count=%0d", 
                     $time, PADDR, PWRITE, PSEL, PENABLE, PWDATA[7:0], PRDATA[7:0], uut.tx.state, uut.rx.state, TXD, RXD, uut.regs.LSR, uut.regs.LSR[0], uut.regs.rx_fifo_count, uut.regs.tx_fifo_count);
        end
    end

    task automatic apb_write(input logic [4:0] addr, input logic [7:0] data);
        @(posedge PCLK);
        PADDR   = addr;
        PWRITE  = 1;
        PSEL    = 1;
        PWDATA  = {24'd0, data};
        @(posedge PCLK);
        PENABLE = 1;
        @(posedge PCLK);
        PSEL    = 0;
        PENABLE = 0;
    endtask

    task automatic apb_read(input logic [4:0] addr, output logic [7:0] data);
        @(posedge PCLK);
        PADDR   = addr;
        PWRITE  = 0;
        PSEL    = 1;
        @(posedge PCLK);
        PENABLE = 1;
        #5;
        data    = PRDATA[7:0];
        @(posedge PCLK);
        PSEL    = 0;
        PENABLE = 0;
    endtask

    initial begin
        logic [7:0] rdata;
        PCLK    = 0;
        PRESETn = 0;
        PADDR   = 0;
        PSEL    = 0;
        PENABLE = 0;
        PWRITE  = 0;
        PWDATA  = 0;

        #40;
        PRESETn = 1;
        #40;

        $display("Starting APB UART Testbench...");
        $fflush();

        apb_write(5'h0C, 8'h80);
        apb_write(5'h00, 8'h04);
        apb_write(5'h04, 8'h00);
        apb_write(5'h0C, 8'h03);

        apb_write(5'h08, 8'h07);

        apb_write(5'h1C, 8'hA5);
        apb_read(5'h1C, rdata);
        if (rdata !== 8'hA5) $display("FAIL: Scratchpad - Got %2h", rdata);
        else $display("PASS: Scratchpad");
        $fflush();

        apb_write(5'h00, 8'h5A);
        
        rdata = 8'h00;
        while ((rdata & 8'h01) == 0) begin
            apb_read(5'h14, rdata);
            #20;
        end

        apb_read(5'h00, rdata);
        if (rdata !== 8'h5A) $display("FAIL: Loopback - Got %2h", rdata);
        else $display("PASS: Loopback");
        $fflush();

        apb_write(5'h00, 8'h11);
        apb_write(5'h00, 8'h22);
        apb_write(5'h00, 8'h33);

        #100000; 

        apb_read(5'h00, rdata);
        if (rdata !== 8'h11) $display("FAIL: Bulk 1 - Got %2h", rdata);
        apb_read(5'h00, rdata);
        if (rdata !== 8'h22) $display("FAIL: Bulk 2 - Got %2h", rdata);
        apb_read(5'h00, rdata);
        if (rdata !== 8'h33) $display("FAIL: Bulk 3 - Got %2h", rdata);
        else $display("PASS: Bulk loopback");
        $fflush();

        #100;
        $display("APB UART Test Done.");
        $fflush();
        $finish;
    end

endmodule
