module uart_rx (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       bclk_en,
    input  logic       rxd,
    output logic [7:0] rx_data,
    output logic       rx_valid,
    output logic       err_pe,
    output logic       err_fe,
    output logic       err_bi
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_START,
        ST_DATA,
        ST_PARITY,
        ST_STOP,
        ST_VALID
    } state_t;

    state_t state;

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

    logic [7:0] shift_reg;
    logic [3:0] bclk_count;
    logic [2:0] bit_count;
    logic       rx_parity_bit;
    logic       rx_stop_bit;
    
    localparam logic [2:0] max_bit_index = 3'd7;
    logic expected_parity;

    assign expected_parity = ^shift_reg;
    assign rx_data         = shift_reg;

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
                        if (bclk_count == 4'd7) begin // Sample middle of START bit
                            if (rxd_sync == 1'b0) begin
                                bclk_count <= 4'd0;
                                state      <= ST_DATA;
                            end else begin
                                state      <= ST_IDLE;
                            end
                        end else begin
                            bclk_count <= bclk_count + 4'd1;
                        end
                    end
                end

                ST_DATA: begin
                    if (bclk_en) begin
                        if (bclk_count == 4'd15) begin // Sample middle of data bits
                            bclk_count           <= 4'd0;
                            shift_reg[bit_count] <= rxd_sync;
                            if (bit_count == max_bit_index) begin
                                state <= ST_PARITY;
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
                    err_fe   <= ~rx_stop_bit;
                    err_pe   <= (rx_parity_bit !== expected_parity);
                    err_bi   <= (rx_data == 8'd0) && (rx_parity_bit == 1'b0) && (rx_stop_bit == 1'b0);
                    state    <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
