module async_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH = 16
) (
    input  logic                  wr_clk_i,
    input  logic                  wr_rst_ni,
    input  logic                  wr_en_i,
    input  logic [DATA_WIDTH-1:0] wr_data_i,
    output logic                  full_o,

    input  logic                  rd_clk_i,
    input  logic                  rd_rst_ni,
    input  logic                  rd_en_i,
    output logic [DATA_WIDTH-1:0] rd_data_o,
    output logic                  empty_o
);

    localparam int ADDR_WIDTH = $clog2(DEPTH);
    localparam int PTR_WIDTH = ADDR_WIDTH + 1;

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [PTR_WIDTH-1:0] wr_bin_q;
    logic [PTR_WIDTH-1:0] wr_bin_next;
    logic [PTR_WIDTH-1:0] wr_gray_q;
    logic [PTR_WIDTH-1:0] wr_gray_next;

    logic [PTR_WIDTH-1:0] rd_bin_q;
    logic [PTR_WIDTH-1:0] rd_bin_next;
    logic [PTR_WIDTH-1:0] rd_gray_q;
    logic [PTR_WIDTH-1:0] rd_gray_next;

    (* async_reg = "true" *) logic [PTR_WIDTH-1:0] rd_gray_sync1_q;
    (* async_reg = "true" *) logic [PTR_WIDTH-1:0] rd_gray_sync2_q;

    (* async_reg = "true" *) logic [PTR_WIDTH-1:0] wr_gray_sync1_q;
    (* async_reg = "true" *) logic [PTR_WIDTH-1:0] wr_gray_sync2_q;

    logic full_next;
    logic empty_next;

    initial begin
        if (DEPTH < 4 || (DEPTH & (DEPTH - 1)) != 0) begin
            $error("DEPTH must be a power of two and at least 4");
        end
    end

    always_comb begin
        wr_bin_next = wr_bin_q;

        if (wr_en_i && !full_o) begin
            wr_bin_next = wr_bin_q + 1'b1;
        end

        wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;
    end

    always_ff @(posedge wr_clk_i or negedge wr_rst_ni) begin
        if (!wr_rst_ni) begin
            wr_bin_q  <= '0;
            wr_gray_q <= '0;
            full_o    <= 1'b0;
        end else begin
            wr_bin_q  <= wr_bin_next;
            wr_gray_q <= wr_gray_next;
            full_o    <= full_next;

            if (wr_en_i && !full_o) begin
                mem[wr_bin_q[ADDR_WIDTH-1:0]] <= wr_data_i;
            end
        end
    end

    always_comb begin
        rd_bin_next = rd_bin_q;

        if (rd_en_i && !empty_o) begin
            rd_bin_next = rd_bin_q + 1'b1;
        end

        rd_gray_next = (rd_bin_next >> 1) ^ rd_bin_next;
    end

    always_ff @(posedge rd_clk_i or negedge rd_rst_ni) begin
        if (!rd_rst_ni) begin
            rd_bin_q  <= '0;
            rd_gray_q <= '0;
            rd_data_o <= '0;
            empty_o   <= 1'b1;
        end else begin
            rd_bin_q  <= rd_bin_next;
            rd_gray_q <= rd_gray_next;
            empty_o   <= empty_next;

            if (rd_en_i && !empty_o) begin
                rd_data_o <= mem[rd_bin_q[ADDR_WIDTH-1:0]];
            end
        end
    end

    always_ff @(posedge wr_clk_i or negedge wr_rst_ni) begin
        if (!wr_rst_ni) begin
            rd_gray_sync1_q <= '0;
            rd_gray_sync2_q <= '0;
        end else begin
            rd_gray_sync1_q <= rd_gray_q;
            rd_gray_sync2_q <= rd_gray_sync1_q;
        end
    end

    always_ff @(posedge rd_clk_i or negedge rd_rst_ni) begin
        if (!rd_rst_ni) begin
            wr_gray_sync1_q <= '0;
            wr_gray_sync2_q <= '0;
        end else begin
            wr_gray_sync1_q <= wr_gray_q;
            wr_gray_sync2_q <= wr_gray_sync1_q;
        end
    end

    assign empty_next = (rd_gray_next == wr_gray_sync2_q);

    assign full_next = (
        wr_gray_next ==
        {
            ~rd_gray_sync2_q[PTR_WIDTH-1:PTR_WIDTH-2],
             rd_gray_sync2_q[PTR_WIDTH-3:0]
        }
    );

endmodule
