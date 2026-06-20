module uart_regs (
    input  logic        clk,
    input  logic        rst_n,

    // Bus Register Interface
    input  logic [4:0]  reg_addr,
    input  logic        reg_write,
    input  logic        reg_read,
    input  logic [7:0]  reg_wdata,
    output logic [7:0]  reg_rdata,

    // Interrupt Line
    output logic        intr,

    // Divisor and config outputs to engines
    output logic [15:0] divisor,
    output logic [1:0]  cfg_wls,
    output logic        cfg_stb,
    output logic        cfg_pen,
    output logic        cfg_eps,
    output logic        cfg_bc,

    // Engine Interfaces
    input  logic        bclk_en,
    output logic [7:0]  tx_data,
    output logic        tx_start,
    input  logic        tx_busy,
    input  logic        tx_done,
    input  logic [7:0]  rx_data,
    input  logic        rx_valid,
    input  logic        rx_err_pe,
    input  logic        rx_err_fe,
    input  logic        rx_err_bi
);

    // Internal Registers
    logic [7:0] IER;
    logic [7:0] LCR;
    logic [7:0] FCR;
    logic [7:0] SCR;
    logic [7:0] DLL;
    logic [7:0] DLH;

    assign divisor = {DLH, DLL};
    assign cfg_wls = LCR[1:0];
    assign cfg_stb = LCR[2];
    assign cfg_pen = LCR[3];
    assign cfg_eps = LCR[4];
    assign cfg_bc  = LCR[6];

    // FIFO Instantiations
    logic tx_fifo_clear;
    logic tx_fifo_write;
    logic tx_fifo_read;
    logic [7:0] tx_fifo_rdata;
    logic tx_fifo_full;
    logic tx_fifo_empty;
    logic [4:0] tx_fifo_count;

    assign tx_fifo_clear = FCR[2];
    assign tx_fifo_write = reg_write && (reg_addr == 5'h00) && !LCR[7];

    fifo #(
        .DEPTH(16),
        .WIDTH(8)
    ) tx_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .clear(tx_fifo_clear),
        .wdata(reg_wdata),
        .write(tx_fifo_write),
        .read(tx_fifo_read),
        .rdata(tx_fifo_rdata),
        .full(tx_fifo_full),
        .empty(tx_fifo_empty),
        .count(tx_fifo_count)
    );

    logic rx_fifo_clear;
    logic rx_fifo_write;
    logic rx_fifo_read;
    logic [10:0] rx_fifo_wdata;
    logic [10:0] rx_fifo_rdata;
    logic rx_fifo_full;
    logic rx_fifo_empty;
    logic [4:0] rx_fifo_count;

    assign rx_fifo_clear = FCR[1];
    assign rx_fifo_write = rx_valid;
    assign rx_fifo_wdata = {rx_err_bi, rx_err_fe, rx_err_pe, rx_data};
    assign rx_fifo_read  = reg_read && (reg_addr == 5'h00) && !LCR[7];

    fifo #(
        .DEPTH(16),
        .WIDTH(11)
    ) rx_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .clear(rx_fifo_clear),
        .wdata(rx_fifo_wdata),
        .write(rx_fifo_write),
        .read(rx_fifo_read),
        .rdata(rx_fifo_rdata),
        .full(rx_fifo_full),
        .empty(rx_fifo_empty),
        .count(rx_fifo_count)
    );

    // TX Pop & Launch Logic
    logic tx_start_reg;
    assign tx_fifo_read = tx_start_reg;
    assign tx_data      = tx_fifo_rdata;
    assign tx_start     = tx_start_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_start_reg <= 1'b0;
        end else begin
            if (!tx_fifo_empty && !tx_busy && !tx_start_reg) begin
                tx_start_reg <= 1'b1;
            end else begin
                tx_start_reg <= 1'b0;
            end
        end
    end

    // LSR Sticky and FIFO Error Tracking
    logic overrun_sticky;
    logic [4:0] error_byte_count;
    logic fifo_err_pe, fifo_err_fe, fifo_err_bi;

    assign {fifo_err_bi, fifo_err_fe, fifo_err_pe} = rx_fifo_empty ? 3'b000 : rx_fifo_rdata[10:8];

    // Tracking error bytes count in RX FIFO
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error_byte_count <= '0;
            overrun_sticky   <= 1'b0;
        end else begin
            if (rx_fifo_clear) begin
                error_byte_count <= '0;
            end else begin
                // Update error count
                case ({rx_fifo_write && !rx_fifo_full && (|rx_fifo_wdata[10:8]), 
                       rx_fifo_read && !rx_fifo_empty && (|rx_fifo_rdata[10:8])})
                    2'b10: error_byte_count <= error_byte_count + 1'b1;
                    2'b01: error_byte_count <= error_byte_count - 1'b1;
                    default: error_byte_count <= error_byte_count;
                endcase
            end

            // Overrun detection
            if (rx_valid && rx_fifo_full) begin
                overrun_sticky <= 1'b1;
            end else if (reg_read && (reg_addr == 5'h14)) begin
                overrun_sticky <= 1'b0; // Clear on LSR read
            end
        end
    end

    // Character Timeout Logic
    logic [10:0] timeout_counter;
    logic [10:0] timeout_limit;
    logic        timeout_occurred;
    logic [3:0]  char_bits;

    assign char_bits = 4'd1 + {2'd0, cfg_wls} + 4'd5 + {3'd0, cfg_pen} + 4'd1;
    assign timeout_limit = {4'd0, char_bits, 3'd0}; // char_bits * 8 * 8 = char_bits * 64 ticks

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timeout_counter  <= '0;
            timeout_occurred <= 1'b0;
        end else begin
            if (rx_fifo_write || rx_fifo_read || rx_fifo_empty) begin
                timeout_counter  <= '0;
                if (rx_fifo_read) begin
                    timeout_occurred <= 1'b0;
                end
            end else if (bclk_en) begin
                if (timeout_counter >= timeout_limit - 1'b1) begin
                    timeout_occurred <= 1'b1;
                end else begin
                    timeout_counter <= timeout_counter + 1'b1;
                end
            end
        end
    end

    // Line Status Register (LSR) Build
    logic [7:0] LSR;
    assign LSR[0] = !rx_fifo_empty;
    assign LSR[1] = overrun_sticky;
    assign LSR[2] = fifo_err_pe;
    assign LSR[3] = fifo_err_fe;
    assign LSR[4] = fifo_err_bi;
    assign LSR[5] = tx_fifo_empty;
    assign LSR[6] = tx_fifo_empty && !tx_busy;
    assign LSR[7] = (error_byte_count > 0);

    // Interrupt Priority Controller
    logic ls_intr_pending;
    logic da_intr_pending;
    logic to_intr_pending;
    logic thre_intr_pending;
    logic thre_intr_active;
    logic tx_fifo_empty_d1;
    
    logic [2:0] iir_intid;
    logic       iir_ipend;
    logic       iir_read;

    assign ls_intr_pending = IER[2] && (|LSR[4:1]);
    
    logic [3:0] rx_trigger_level;
    always_comb begin
        case (FCR[7:6])
            2'b00:   rx_trigger_level = 4'd1;
            2'b01:   rx_trigger_level = 4'd4;
            2'b10:   rx_trigger_level = 4'd8;
            default: rx_trigger_level = 4'd14;
        endcase
    end
    assign da_intr_pending = IER[0] && (rx_fifo_count >= rx_trigger_level);
    assign to_intr_pending = IER[0] && timeout_occurred;

    // THRE Interrupt Logic
    assign iir_read = reg_read && (reg_addr == 5'h08);
    assign thre_intr_pending = IER[1] && tx_fifo_empty && thre_intr_active;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_fifo_empty_d1 <= 1'b1;
            thre_intr_active <= 1'b1; // Reset to active to trigger initial write
        end else begin
            tx_fifo_empty_d1 <= tx_fifo_empty;
            if (tx_fifo_empty && !tx_fifo_empty_d1) begin
                thre_intr_active <= 1'b1;
            end else if (tx_fifo_write) begin
                thre_intr_active <= 1'b0;
            end else if (iir_read && (iir_intid == 3'b001)) begin
                thre_intr_active <= 1'b0;
            end
        end
    end

    // Priority Encoder
    always_comb begin
        if (ls_intr_pending) begin
            iir_intid = 3'b011;
            iir_ipend = 1'b0;
        end else if (to_intr_pending) begin
            iir_intid = 3'b110;
            iir_ipend = 1'b0;
        end else if (da_intr_pending) begin
            iir_intid = 3'b010;
            iir_ipend = 1'b0;
        end else if (thre_intr_pending) begin
            iir_intid = 3'b001;
            iir_ipend = 1'b0;
        end else begin
            iir_intid = 3'b000;
            iir_ipend = 1'b1;
        end
    end

    assign intr = !iir_ipend;

    // Bus Registers Read Mapping
    always_comb begin
        case (reg_addr)
            5'h00:   reg_rdata = LCR[7] ? DLL : rbr_data_read();
            5'h04:   reg_rdata = LCR[7] ? DLH : IER;
            5'h08:   reg_rdata = {FCR[0] ? 2'b11 : 2'b00, 2'b00, iir_intid, iir_ipend};
            5'h0C:   reg_rdata = LCR;
            5'h14:   reg_rdata = LSR;
            5'h1C:   reg_rdata = SCR;
            default: reg_rdata = 8'h00;
        endcase
    end

    function automatic logic [7:0] rbr_data_read();
        return rx_fifo_empty ? 8'h00 : rx_fifo_rdata[7:0];
    endfunction

    // Bus Registers Write Mapping
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            IER <= 8'h00;
            LCR <= 8'h00;
            FCR <= 8'h00;
            SCR <= 8'h00;
            DLL <= 8'h00;
            DLH <= 8'h00;
        end else begin
            // FCR self-clearing clear flags
            FCR[1] <= 1'b0; // rx clear
            FCR[2] <= 1'b0; // tx clear

            if (reg_write) begin
                case (reg_addr)
                    5'h00: begin
                        if (LCR[7]) DLL <= reg_wdata;
                    end
                    5'h04: begin
                        if (LCR[7]) begin
                            DLH <= reg_wdata;
                        end else begin
                            IER <= reg_wdata;
                        end
                    end
                    5'h08: begin
                        FCR <= reg_wdata;
                    end
                    5'h0C: begin
                        LCR <= reg_wdata;
                    end
                    5'h1C: begin
                        SCR <= reg_wdata;
                    end
                    default: ;
                endcase
            end
        end
    end

endmodule
