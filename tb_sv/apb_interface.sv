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

`ifndef __ICARUS__
    // SystemVerilog Assertions (SVA) for APB protocol compliance

    // 1. Setup Phase: PENABLE must be low when PSEL rises
    property p_apb_setup;
        @(posedge PCLK) disable iff (!PRESETn)
        $rose(PSEL) -> !PENABLE;
    endproperty
    assert_apb_setup: assert property(p_apb_setup);

    // 2. Control/Address signals must stay stable between setup and access phase
    property p_apb_addr_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && !PENABLE) -> ##1 (PSEL && PENABLE -> $stable(PADDR));
    endproperty
    assert_apb_addr_stable: assert property(p_apb_addr_stable);

    property p_apb_write_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && !PENABLE) -> ##1 (PSEL && PENABLE -> $stable(PWRITE));
    endproperty
    assert_apb_write_stable: assert property(p_apb_write_stable);
`endif

endinterface
