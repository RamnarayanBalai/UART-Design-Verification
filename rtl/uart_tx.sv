module uart_tx (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       bclk_en,
    input  logic [7:0] tx_data,
    input  logic       tx_start,
    input  logic       cfg_bc,
    output logic       txd,
    output logic       tx_busy,
    output logic       tx_done
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_START,
        ST_DATA,
        ST_PARITY,
        ST_STOP,
        ST_DONE
    } state_t;

    state_t state;
    
    logic [7:0] shift_reg;
    logic [5:0] bclk_count;
    logic [2:0] bit_count;
    logic       parity_bit;
    logic       tx_out;

    localparam logic [2:0] max_bit_index  = 3'd7;
    localparam logic [5:0] stop_bit_ticks = 6'd16;

    always_comb begin
        case (state)
            ST_IDLE:   tx_out = 1'b1;
            ST_START:  tx_out = 1'b0;
            ST_DATA:   tx_out = shift_reg[0];
            ST_PARITY: tx_out = parity_bit;
            ST_STOP:   tx_out = 1'b1;
            default:   tx_out = 1'b1;
        endcase
    end

    assign txd = cfg_bc ? 1'b0 : tx_out;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            shift_reg    <= 8'd0;
            bclk_count   <= 6'd0;
            bit_count    <= 3'd0;
            tx_busy      <= 1'b0;
            tx_done      <= 1'b0;
            parity_bit   <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    tx_busy      <= 1'b0;
                    tx_done      <= 1'b0;
                    bclk_count   <= 6'd0;
                    bit_count    <= 3'd0;
                    if (tx_start) begin
                        shift_reg  <= tx_data;
                        state      <= ST_START;
                        tx_busy    <= 1'b1;
                        parity_bit <= ^tx_data; // Even parity
                    end
                end

                ST_START: begin
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
                    if (bclk_en) begin
                        if (bclk_count == 6'd15) begin
                            bclk_count <= 6'd0;
                            shift_reg  <= shift_reg >> 1;
                            if (bit_count == max_bit_index) begin
                                state <= ST_PARITY;
                            end else begin
                                bit_count <= bit_count + 3'd1;
                            end
                        end else begin
                            bclk_count <= bclk_count + 6'd1;
                        end
                    end
                end

                ST_PARITY: begin
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
