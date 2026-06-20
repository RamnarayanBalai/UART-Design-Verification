module apb_uart (
    input  logic        PCLK,
    input  logic        PRESETn,
    input  logic [4:0]  PADDR,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PSLVERR,

    // Serial Interface
    output logic        TXD,
    input  logic        RXD,
    output logic        INTR
);

    // Divisor and control configurations
    logic [15:0] divisor;
    logic [1:0]  cfg_wls;
    logic        cfg_stb;
    logic        cfg_pen;
    logic        cfg_eps;
    logic        cfg_bc;

    // Engine control connections
    logic        bclk;
    logic        bclk_en;
    logic [7:0]  tx_data;
    logic        tx_start;
    logic        tx_busy;
    logic        tx_done;
    logic [7:0]  rx_data;
    logic        rx_valid;
    logic        rx_err_pe;
    logic        rx_err_fe;
    logic        rx_err_bi;

    // Register interface signals
    logic        reg_write;
    logic        reg_read;
    logic [7:0]  reg_rdata;

    // APB to Register file mappings
    assign reg_write = PSEL && PENABLE && PWRITE;
    assign reg_read  = PSEL && !PWRITE;
    assign PRDATA    = {24'd0, reg_rdata};
    assign PREADY    = 1'b1;
    assign PSLVERR   = 1'b0;

    // Module Instantiations
    baud_rate_generator brg (
        .clk(PCLK),
        .rst_n(PRESETn),
        .divisor(divisor),
        .bclk(bclk),
        .bclk_en(bclk_en)
    );

    uart_tx tx (
        .clk(PCLK),
        .rst_n(PRESETn),
        .bclk_en(bclk_en),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .cfg_wls(cfg_wls),
        .cfg_stb(cfg_stb),
        .cfg_pen(cfg_pen),
        .cfg_eps(cfg_eps),
        .cfg_bc(cfg_bc),
        .txd(TXD),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );

    uart_rx rx (
        .clk(PCLK),
        .rst_n(PRESETn),
        .bclk_en(bclk_en),
        .rxd(RXD),
        .cfg_wls(cfg_wls),
        .cfg_pen(cfg_pen),
        .cfg_eps(cfg_eps),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .err_pe(rx_err_pe),
        .err_fe(rx_err_fe),
        .err_bi(rx_err_bi)
    );

    uart_regs regs (
        .clk(PCLK),
        .rst_n(PRESETn),
        .reg_addr(PADDR),
        .reg_write(reg_write),
        .reg_read(reg_read),
        .reg_wdata(PWDATA[7:0]),
        .reg_rdata(reg_rdata),
        .intr(INTR),
        .divisor(divisor),
        .cfg_wls(cfg_wls),
        .cfg_stb(cfg_stb),
        .cfg_pen(cfg_pen),
        .cfg_eps(cfg_eps),
        .cfg_bc(cfg_bc),
        .bclk_en(bclk_en),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_err_pe(rx_err_pe),
        .rx_err_fe(rx_err_fe),
        .rx_err_bi(rx_err_bi)
    );

endmodule
