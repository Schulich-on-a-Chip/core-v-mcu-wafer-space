`timescale 1ns/1ps

module tb_async_fifo #(
    parameter realtime WR_HALF_PERIOD = 71.429,
    parameter realtime RD_HALF_PERIOD = 7.143
);

    localparam int DATA_WIDTH = 32;
    localparam int DEPTH = 16;

    logic                  wr_clk_i;
    logic                  wr_rst_ni;
    logic                  wr_en_i;
    logic [DATA_WIDTH-1:0] wr_data_i;
    logic                  full_o;

    logic                  rd_clk_i;
    logic                  rd_rst_ni;
    logic                  rd_en_i;
    logic [DATA_WIDTH-1:0] rd_data_o;
    logic                  empty_o;

    integer i;

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .wr_clk_i  (wr_clk_i),
        .wr_rst_ni (wr_rst_ni),
        .wr_en_i   (wr_en_i),
        .wr_data_i (wr_data_i),
        .full_o    (full_o),
        .rd_clk_i  (rd_clk_i),
        .rd_rst_ni (rd_rst_ni),
        .rd_en_i   (rd_en_i),
        .rd_data_o (rd_data_o),
        .empty_o   (empty_o)
    );

    initial begin
        wr_clk_i = 1'b0;
        forever #(WR_HALF_PERIOD) wr_clk_i = ~wr_clk_i;
    end

    initial begin
        rd_clk_i = 1'b0;
        #1.337;
        forever #(RD_HALF_PERIOD) rd_clk_i = ~rd_clk_i;
    end

    task automatic write_word(input logic [DATA_WIDTH-1:0] value);
        begin
            while (full_o) begin
                @(negedge wr_clk_i);
            end

            @(negedge wr_clk_i);
            wr_data_i = value;
            wr_en_i = 1'b1;

            @(negedge wr_clk_i);
            wr_en_i = 1'b0;
        end
    endtask

    task automatic read_and_check(input logic [DATA_WIDTH-1:0] expected);
        begin
            while (empty_o) begin
                @(negedge rd_clk_i);
            end

            @(negedge rd_clk_i);
            rd_en_i = 1'b1;

            @(negedge rd_clk_i);
            rd_en_i = 1'b0;

            if (rd_data_o !== expected) begin
                $fatal(
                    1,
                    "Read mismatch: expected 0x%08h, received 0x%08h",
                    expected,
                    rd_data_o
                );
            end
        end
    endtask

    initial begin
        $dumpfile("async_fifo_wave.vcd");
        $dumpvars(0, tb_async_fifo);

        wr_rst_ni = 1'b0;
        rd_rst_ni = 1'b0;
        wr_en_i = 1'b0;
        wr_data_i = '0;
        rd_en_i = 1'b0;

        repeat (4) @(posedge wr_clk_i);
        wr_rst_ni = 1'b1;
        rd_rst_ni = 1'b1;

        repeat (3) @(posedge wr_clk_i);

        if (full_o !== 1'b0) begin
            $fatal(1, "FIFO was full after reset");
        end

        if (empty_o !== 1'b1) begin
            $fatal(1, "FIFO was not empty after reset");
        end

        $display("PASS: reset state");

        write_word(32'h11111111);
        write_word(32'h22222222);
        write_word(32'h33333333);
        write_word(32'h44444444);

        read_and_check(32'h11111111);
        read_and_check(32'h22222222);
        read_and_check(32'h33333333);
        read_and_check(32'h44444444);

        $display("PASS: data order across unrelated clocks");

        repeat (3) @(posedge rd_clk_i);

        if (empty_o !== 1'b1) begin
            $fatal(1, "FIFO did not become empty");
        end

        $display("PASS: empty detection");

        for (i = 0; i < DEPTH; i = i + 1) begin
            write_word(32'h10000000 + i);
        end

        repeat (2) @(posedge wr_clk_i);

        if (full_o !== 1'b1) begin
            $fatal(1, "FIFO did not become full");
        end

        $display("PASS: full detection");

        @(negedge wr_clk_i);
        wr_data_i = 32'hDEADBEEF;
        wr_en_i = 1'b1;
        @(negedge wr_clk_i);
        wr_en_i = 1'b0;

        for (i = 0; i < DEPTH; i = i + 1) begin
            read_and_check(32'h10000000 + i);
        end

        $display("PASS: full write protection and pointer wraparound");

        repeat (3) @(posedge rd_clk_i);

        if (empty_o !== 1'b1) begin
            $fatal(1, "FIFO was not empty at the end of the test");
        end

        $display("PASS: all asynchronous FIFO tests completed");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Simulation timed out");
    end

endmodule
