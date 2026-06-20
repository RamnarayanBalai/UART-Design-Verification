interface uart_interface;
    logic TXD;
    logic RXD;

`ifndef __ICARUS__
    // SVA for serial line properties
    
    // 1. When TX is idle, TXD must be high
    property p_tx_idle_high;
        @(posedge tb_top.PCLK) 
        (tb_top.dut.tx.state == tb_top.dut.tx.ST_IDLE) -> TXD === 1'b1;
    endproperty
    assert_tx_idle_high: assert property(p_tx_idle_high);

    // 2. When TX is in START state, TXD must be low
    property p_tx_start_low;
        @(posedge tb_top.PCLK)
        (tb_top.dut.tx.state == tb_top.dut.tx.ST_START) -> TXD === 1'b0;
    endproperty
    assert_tx_start_low: assert property(p_tx_start_low);

    // 3. When TX is in STOP state, TXD must be high
    property p_tx_stop_high;
        @(posedge tb_top.PCLK)
        (tb_top.dut.tx.state == tb_top.dut.tx.ST_STOP) -> TXD === 1'b1;
    endproperty
    assert_tx_stop_high: assert property(p_tx_stop_high);
`endif

endinterface
