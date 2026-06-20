module uart_tx_sva (
    input logic       clk,
    input logic       rst_n,
    input logic       txd,
    input logic [2:0] state
);

    // FSM States decoding
    localparam logic [2:0] ST_IDLE  = 3'b000;
    localparam logic [2:0] ST_START = 3'b001;
    localparam logic [2:0] ST_STOP  = 3'b100;

    // 1. Idle state: txd must be driven high
    property p_tx_idle_high;
        @(posedge clk) disable iff (!rst_n)
        (state == ST_IDLE) -> txd === 1'b1;
    endproperty
    assert_tx_idle_high: assert property(p_tx_idle_high);

    // 2. Start state: txd must be driven low
    property p_tx_start_low;
        @(posedge clk) disable iff (!rst_n)
        (state == ST_START) -> txd === 1'b0;
    endproperty
    assert_tx_start_low: assert property(p_tx_start_low);

    // 3. Stop state: txd must be driven high
    property p_tx_stop_high;
        @(posedge clk) disable iff (!rst_n)
        (state == ST_STOP) -> txd === 1'b1;
    endproperty
    assert_tx_stop_high: assert property(p_tx_stop_high);

endmodule
