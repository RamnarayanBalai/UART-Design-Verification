module fifo #(
    parameter int DEPTH = 16,
    parameter int WIDTH = 8
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             clear,
    input  logic [WIDTH-1:0] wdata,
    input  logic             write,
    input  logic             read,
    output logic [WIDTH-1:0] rdata,
    output logic             full,
    output logic             empty,
    output logic [$clog2(DEPTH):0] count
);

    logic [WIDTH-1:0] mem [DEPTH-1:0];
    logic [$clog2(DEPTH)-1:0] wptr;
    logic [$clog2(DEPTH)-1:0] rptr;

    assign empty = (count == '0);
    assign full  = (count == DEPTH[31:0]);

    // First-Word Fall-Through (FWFT) read
    assign rdata = empty ? '0 : mem[rptr];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr  <= '0;
            rptr  <= '0;
            count <= '0;
        end else begin
            if (clear) begin
                wptr  <= '0;
                rptr  <= '0;
                count <= '0;
            end else begin
                if (write && !full) begin
                    mem[wptr] <= wdata;
                    wptr      <= wptr + 1'b1;
                end

                if (read && !empty) begin
                    rptr      <= rptr + 1'b1;
                end

                case ({write && !full, read && !empty})
                    2'b10: count <= count + 1'b1;
                    2'b01: count <= count - 1'b1;
                    default: count <= count;
                endcase
            end
        end
    end

endmodule
