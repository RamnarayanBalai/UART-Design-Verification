// =============================================================================
// Module: uart_rx
// Project: UART Design & Verification
// Description: Serial receiver engine. Deserializes incoming UART frames.
//              Uses 16x oversampling, detects start bit, samples bits at the
//              middle of the bit period, and performs error checks (parity,
//              framing, break detection).
// =============================================================================

`timescale 1ns / 1ps

module uart_rx (
    input  logic       clk,            // System clock
    input  logic       rst_n,          // Active-low asynchronous reset
    input  logic       bclk_en,        // 16x oversampling baud clock enable
    input  logic       rxd,            // Serial input line
    input  logic [1:0] cfg_wls,        // Word length select: 00=5b, 01=6b, 10=7b, 11=8b
    input  logic       cfg_pen,        // Parity enable
    input  logic       cfg_eps,        // Even parity select (0=odd, 1=even)
    output logic [7:0] rx_data,        // 8-bit received parallel data
    output logic       rx_valid,       // Single-cycle received data valid pulse
    output logic       err_pe,         // Parity error flag for current character
    output logic       err_fe,         // Framing error flag for current character
    output logic       err_bi          // Break indicator flag for current character
);

    // FSM States
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_START,
        ST_DATA,
        ST_PARITY,
        ST_STOP,
        ST_VALID
    } state_t;

    state_t state;

    // Double-flop synchronizer for RXD to prevent metastability
    logic rxd_sync1;
    logic rxd_sync;
    logic rxd_d1;
    logic falling_edge;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rxd_sync1 <= 1'b1;
            rxd_sync  <= 1'b1;
            rxd_d1    <= 1'b1;
        end else begin
            rxd_sync1 <= rxd;
            rxd_sync  <= rxd_sync1;
            rxd_d1    <= rxd_sync;
        end
    end

    assign falling_edge = (rxd_d1 && !rxd_sync);

    // Internal registers
    logic [7:0] shift_reg;
    logic [3:0] bclk_count; // Counts 0 to 15 ticks for oversampling
    logic [2:0] bit_count;
    logic       rx_parity_bit;
    logic       rx_stop_bit;
    
    // Configurable parameters
    logic [2:0] max_bit_index;
    logic       expected_parity;

    // Determine data bit length index (number of data bits - 1)
    always_comb begin
        case (cfg_wls)
            2'b00:   max_bit_index = 3'd4; // 5 bits
            2'b01:   max_bit_index = 3'd5; // 6 bits
            2'b10:   max_bit_index = 3'd6; // 7 bits
            default: max_bit_index = 3'd7; // 8 bits
        endcase
    end

    // Expected parity calculation logic
    always_comb begin
        logic temp_parity;
        case (cfg_wls)
            2'b00:   temp_parity = ^shift_reg[4:0];
            2'b01:   temp_parity = ^shift_reg[5:0];
            2'b10:   temp_parity = ^shift_reg[6:0];
            default: temp_parity = ^shift_reg[7:0];
        endcase
        
        if (cfg_eps) begin
            expected_parity = temp_parity;       // Even Parity (XOR)
        end else begin
            expected_parity = ~temp_parity;      // Odd Parity (XNOR)
        end
    end

    // Format received data output (mask unused bits)
    always_comb begin
        case (cfg_wls)
            2'b00:   rx_data = {3'b000, shift_reg[4:0]};
            2'b01:   rx_data = {2'b00,  shift_reg[5:0]};
            2'b10:   rx_data = {1'b0,   shift_reg[6:0]};
            default: rx_data = shift_reg;
        endcase
    end

    // FSM Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            shift_reg     <= 8'd0;
            bclk_count    <= 4'd0;
            bit_count     <= 3'd0;
            rx_parity_bit <= 1'b0;
            rx_stop_bit   <= 1'b1;
            rx_valid      <= 1'b0;
            err_pe        <= 1'b0;
            err_fe        <= 1'b0;
            err_bi        <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    rx_valid   <= 1'b0;
                    bclk_count <= 4'd0;
                    bit_count  <= 3'd0;
                    if (falling_edge) begin
                        state <= ST_START;
                    end
                end

                ST_START: begin
                    if (bclk_en) begin
                        if (bclk_count == 4'd7) begin // Sample at the middle of START bit
                            if (rxd_sync == 1'b0) begin
                                bclk_count <= 4'd0;
                                state      <= ST_DATA;
                            end else begin
                                state      <= ST_IDLE; // False start glitch filter
                            end
                        end else begin
                            bclk_count <= bclk_count + 4'd1;
                        end
                    end
                end

                ST_DATA: begin
                    if (bclk_en) begin
                        if (bclk_count == 4'd15) begin // Sample in the middle of data bits
                            bclk_count           <= 4'd0;
                            shift_reg[bit_count] <= rxd_sync;
                            if (bit_count == max_bit_index) begin
                                if (cfg_pen) begin
                                    state <= ST_PARITY;
                                end else begin
                                    state <= ST_STOP;
                                end
                            end else begin
                                bit_count <= bit_count + 3'd1;
                            end
                        end else begin
                            bclk_count <= bclk_count + 4'd1;
                        end
                    end
                end

                ST_PARITY: begin
                    if (bclk_en) begin
                        if (bclk_count == 4'd15) begin
                            bclk_count    <= 4'd0;
                            rx_parity_bit <= rxd_sync;
                            state         <= ST_STOP;
                        end else begin
                            bclk_count <= bclk_count + 4'd1;
                        end
                    end
                end

                ST_STOP: begin
                    if (bclk_en) begin
                        if (bclk_count == 4'd15) begin
                            bclk_count  <= 4'd0;
                            rx_stop_bit <= rxd_sync;
                            state       <= ST_VALID;
                        end else begin
                            bclk_count <= bclk_count + 4'd1;
                        end
                    end
                end

                ST_VALID: begin
                    rx_valid <= 1'b1;
                    
                    // Framing Error: Stop bit must be 1
                    err_fe   <= ~rx_stop_bit;

                    // Parity Error: Check received parity vs expected parity
                    if (cfg_pen) begin
                        err_pe <= (rx_parity_bit !== expected_parity);
                    end else begin
                        err_pe <= 1'b0;
                    end

                    // Break Indicator: RXD is held low for the entire frame
                    // A break is signaled if data, parity (if enabled), and stop bit are all 0
                    if (cfg_pen) begin
                        err_bi <= (rx_data == 8'd0) && (rx_parity_bit == 1'b0) && (rx_stop_bit == 1'b0);
                    end else begin
                        err_bi <= (rx_data == 8'd0) && (rx_stop_bit == 1'b0);
                    end

                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
