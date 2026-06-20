// =============================================================================
// Module: uart_tx
// Project: UART Design & Verification
// Description: Serial transmitter engine. Serializes parallel data into a 
//              standard UART frame. Handles configurable data length (5-8 bits),
//              parity (odd, even, none), stop bits (1, 1.5, 2), and break control.
// =============================================================================

`timescale 1ns / 1ps

module uart_tx (
    input  logic       clk,            // System clock
    input  logic       rst_n,          // Active-low asynchronous reset
    input  logic       bclk_en,        // 16x oversampling baud clock enable
    input  logic [7:0] tx_data,        // 8-bit data to transmit
    input  logic       tx_start,       // Start transmission pulse (from register/FIFO pop)
    input  logic [1:0] cfg_wls,        // Word length select: 00=5b, 01=6b, 10=7b, 11=8b
    input  logic       cfg_stb,        // Stop bit select: 0=1 stop bit, 1=1.5 or 2 stop bits
    input  logic       cfg_pen,        // Parity enable
    input  logic       cfg_eps,        // Even parity select (0=odd, 1=even)
    input  logic       cfg_bc,         // Break control (force TXD low)
    output logic       txd,            // Serial output line
    output logic       tx_busy,        // Transmitter busy indicator
    output logic       tx_done         // Single-cycle transmission done pulse
);

    // FSM States
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_START,
        ST_DATA,
        ST_PARITY,
        ST_STOP,
        ST_DONE
    } state_t;

    state_t state;
    
    // Internal Registers
    logic [7:0] shift_reg;
    logic [5:0] bclk_count; // Counts up to 32 ticks for STOP bit
    logic [2:0] bit_count;
    logic       parity_bit;
    logic       serial_out;

    // Configurable parameters
    logic [2:0] max_bit_index;
    logic [5:0] stop_bit_ticks;

    // Determine bit length index (number of data bits - 1)
    always_comb begin
        case (cfg_wls)
            2'b00:   max_bit_index = 3'd4; // 5 bits
            2'b01:   max_bit_index = 3'd5; // 6 bits
            2'b10:   max_bit_index = 3'd6; // 7 bits
            default: max_bit_index = 3'd7; // 8 bits
        endcase
    end

    // Determine stop bit duration in BCLK cycles (16 BCLK ticks = 1 bit duration)
    always_comb begin
        if (cfg_stb) begin
            if (cfg_wls == 2'b00) begin
                stop_bit_ticks = 6'd24; // 1.5 stop bits
            end else begin
                stop_bit_ticks = 6'd32; // 2.0 stop bits
            end
        end else begin
            stop_bit_ticks = 6'd16; // 1.0 stop bit
        end
    end

    // Parity calculation logic
    always_comb begin
        logic temp_parity;
        case (cfg_wls)
            2'b00:   temp_parity = ^tx_data[4:0];
            2'b01:   temp_parity = ^tx_data[5:0];
            2'b10:   temp_parity = ^tx_data[6:0];
            default: temp_parity = ^tx_data[7:0];
        endcase
        
        if (cfg_eps) begin
            parity_bit = temp_parity;       // Even Parity (XOR)
        end else begin
            parity_bit = ~temp_parity;      // Odd Parity (XNOR)
        end
    end

    // Break control overrides serial out
    assign txd = cfg_bc ? 1'b0 : serial_out;

    // FSM Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            shift_reg    <= 8'd0;
            bclk_count   <= 6'd0;
            bit_count    <= 3'd0;
            serial_out   <= 1'b1;
            tx_busy      <= 1'b0;
            tx_done      <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    serial_out   <= 1'b1;
                    tx_busy      <= 1'b0;
                    tx_done      <= 1'b0;
                    bclk_count   <= 6'd0;
                    bit_count    <= 3'd0;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        state     <= ST_START;
                        tx_busy   <= 1'b1;
                    end
                end

                ST_START: begin
                    serial_out <= 1'b0; // START bit is low
                    if (bclk_en) begin
                        if (bclk_count == 6'd15) begin
                            bclk_count <= 6'd0;
                            state      <= ST_DATA;
                        end else begin
                            bclk_count <= bclk_count + 6'd1;
                        end
                    end
                end

                ST_DATA: begin
                    serial_out <= shift_reg[0];
                    if (bclk_en) begin
                        if (bclk_count == 6'd15) begin
                            bclk_count <= 6'd0;
                            shift_reg  <= shift_reg >> 1;
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
                            bclk_count <= bclk_count + 6'd1;
                        end
                    end
                end

                ST_PARITY: begin
                    serial_out <= parity_bit;
                    if (bclk_en) begin
                        if (bclk_count == 6'd15) begin
                            bclk_count <= 6'd0;
                            state      <= ST_STOP;
                        end else begin
                            bclk_count <= bclk_count + 6'd1;
                        end
                    end
                end

                ST_STOP: begin
                    serial_out <= 1'b1; // STOP bit is high
                    if (bclk_en) begin
                        if (bclk_count == stop_bit_ticks - 6'd1) begin
                            bclk_count <= 6'd0;
                            state      <= ST_DONE;
                        end else begin
                            bclk_count <= bclk_count + 6'd1;
                        end
                    end
                end

                ST_DONE: begin
                    tx_done <= 1'b1;
                    state   <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
