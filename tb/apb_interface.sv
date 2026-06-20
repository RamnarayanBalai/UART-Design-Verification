interface apb_interface(input logic PCLK, input logic PRESETn);
    logic [4:0]  PADDR;
    logic        PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [31:0] PWDATA;
    logic [31:0] PRDATA;
    logic        PREADY;
    logic        PSLVERR;

    clocking cb_driver @(posedge PCLK);
        default input #1ns output #1ns;
        output PADDR, PSEL, PENABLE, PWRITE, PWDATA;
        input  PRDATA, PREADY, PSLVERR;
    endclocking

    clocking cb_monitor @(posedge PCLK);
        default input #1ns output #1ns;
        input PADDR, PSEL, PENABLE, PWRITE, PWDATA, PRDATA, PREADY, PSLVERR;
    endclocking

    modport driver (clocking cb_driver, input PRESETn);
    modport monitor (clocking cb_monitor, input PRESETn);
endinterface
