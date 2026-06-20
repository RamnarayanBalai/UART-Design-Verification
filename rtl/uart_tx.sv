module uart_tx (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       bclk_en,
    input  logic [7:0] tx_data,
    input  logic       tx_start,
    input  logic [1:0] cfg_wls,
    input  logic       cfg_stb,
    input  logic       cfg_pen,
    input  logic       cfg_eps,
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
    logic       serial_out;

    logic [2:0] max_bit_index;
    logic [5:0] stop_bit_ticks;

    always_comb begin
        case (cfg_wls)
            2'b00:   max_bit_index = 3'd4;
            2'b01:   max_bit_index = 3'd5;
            2'b10:   max_bit_index = 3'd6;
            default: max_bit_index = 3'd7;
        endcase
    end

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

    always_comb begin
        logic temp_parity;
        case (cfg_wls)
            2'b00:   temp_parity = ^tx_data[4:0];
            2'b01:   temp_parity = ^tx_data[5:0];
            2'b10:   temp_parity = ^tx_data[6:0];
            default: temp_parity = ^tx_data[7:0];
        endcase
        
        if (cfg_eps) begin
            parity_bit = temp_parity;
        end else begin
            parity_bit = ~temp_parity;
        end
    end

    assign txd = cfg_bc ? 1'b0 : serial_out;

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
                    serial_out <= 1'b0;
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
                    serial_out <= 1'b1;
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
