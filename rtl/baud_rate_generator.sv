module baud_rate_generator (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [15:0] divisor,
    output logic        bclk,
    output logic        bclk_en
);

    logic [15:0] counter;
    logic [15:0] half_divisor;

    assign half_divisor = divisor >> 1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 16'd0;
            bclk    <= 1'b1;
            bclk_en <= 1'b0;
        end else begin
            if (divisor == 16'd0) begin
                counter <= 16'd0;
                bclk    <= 1'b1;
                bclk_en <= 1'b0;
            end else if (divisor == 16'd1) begin
                counter <= 16'd0;
                bclk    <= ~bclk;
                bclk_en <= 1'b1;
            end else begin
                if (counter >= divisor - 16'd1) begin
                    counter <= 16'd0;
                    bclk_en <= 1'b1;
                    bclk    <= 1'b1;
                end else begin
                    counter <= counter + 16'd1;
                    bclk_en <= 1'b0;
                    
                    if (counter == half_divisor - 16'd1) begin
                        bclk <= 1'b0;
                    end
                end
            end
        end
    end

endmodule
