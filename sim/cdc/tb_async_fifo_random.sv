`timescale 1ns/1ps

module tb_async_fifo_random #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH = 16,
    parameter int TRANSACTIONS = 500,
    parameter realtime WR_HALF_PERIOD = 71.429,
    parameter realtime RD_HALF_PERIOD = 7.143
);

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

    logic [DATA_WIDTH-1:0] expected [0:TRANSACTIONS-1];
    integer write_count;
    integer read_count;

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

    task automatic write_one(input logic [DATA_WIDTH-1:0] value);
        integer local_delay;
        begin
            local_delay = $urandom_range(0, 3);
            repeat (local_delay) @(negedge wr_clk_i);

            while (full_o) begin
                @(negedge wr_clk_i);
            end

            wr_data_i = value;
            wr_en_i = 1'b1;
            expected[write_count] = value;

            @(negedge wr_clk_i);
            wr_en_i = 1'b0;
            write_count = write_count + 1;
        end
    endtask

    task automatic read_one;
        integer local_delay;
        begin
            local_delay = $urandom_range(0, 5);
            repeat (local_delay) @(negedge rd_clk_i);

            while (empty_o) begin
                @(negedge rd_clk_i);
            end

            rd_en_i = 1'b1;
            @(negedge rd_clk_i);
            rd_en_i = 1'b0;

            if (rd_data_o !== expected[read_count]) begin
                $fatal(
                    1,
                    "Random test mismatch at item %0d: expected 0x%08h, received 0x%08h",
                    read_count,
                    expected[read_count],
                    rd_data_o
                );
            end

            read_count = read_count + 1;
        end
    endtask

    initial begin
        $dumpfile("async_fifo_random_wave.vcd");
        $dumpvars(0, tb_async_fifo_random);

        wr_rst_ni = 1'b0;
        rd_rst_ni = 1'b0;
        wr_en_i = 1'b0;
        wr_data_i = '0;
        rd_en_i = 1'b0;
        write_count = 0;
        read_count = 0;

        repeat (4) @(posedge wr_clk_i);
        wr_rst_ni = 1'b1;
        rd_rst_ni = 1'b1;

        fork
            begin
                while (write_count < TRANSACTIONS) begin
                    write_one(32'hA5000000 + write_count);
                end
            end

            begin
                while (read_count < TRANSACTIONS) begin
                    read_one();
                end
            end
        join

        repeat (4) @(posedge rd_clk_i);

        if (!empty_o) begin
            $fatal(1, "FIFO was not empty after the random stress test");
        end

        if (write_count != TRANSACTIONS || read_count != TRANSACTIONS) begin
            $fatal(
                1,
                "Transaction count mismatch: wrote %0d, read %0d",
                write_count,
                read_count
            );
        end

        $display(
            "PASS: %0d randomized simultaneous writes and reads completed",
            TRANSACTIONS
        );
        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "Random stress test timed out");
    end

endmodule
