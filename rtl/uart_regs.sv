module uart_regs (
    input  logic        clk,
    input  logic        rst_n,

    // Bus Register Interface
    input  logic [4:0]  reg_addr,
    input  logic        reg_write,
    input  logic        reg_read,
    input  logic [7:0]  reg_wdata,
    output logic [7:0]  reg_rdata,


    // Divisor and config outputs to engines
    output logic [15:0] divisor,
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
    logic [7:0] LCR;
    logic [7:0] FCR;
    logic [7:0] SCR;
    logic [7:0] DLL;
    logic [7:0] DLH;

    assign divisor = {DLH, DLL};
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

    // Bus Registers Read Mapping
    always_comb begin
        case (reg_addr)
            5'h00:   reg_rdata = LCR[7] ? DLL : rbr_data_read();
            5'h04:   reg_rdata = LCR[7] ? DLH : 8'h00;
            5'h08:   reg_rdata = 8'h00;
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
