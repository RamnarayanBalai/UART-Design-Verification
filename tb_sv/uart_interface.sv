interface uart_interface;
    logic TXD;
    logic RXD;

    // Error injection signals
    logic err_inject = 1'b0;
    logic err_val    = 1'b1;
endinterface
