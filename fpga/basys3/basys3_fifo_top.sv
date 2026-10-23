module basys3_fifo_top (
    input  logic        clk,
    input  logic        btnC,
    output logic [15:0] led
);

    logic clk_slow;
    logic clk_fast;
    logic clocks_locked;

    logic [1:0] slow_reset_sync_q;
    logic [1:0] fast_reset_sync_q;
    logic       slow_rst_ni;
    logic       fast_rst_ni;
    logic       reset_async;

    logic        wr_en;
    logic [31:0] wr_data;
    logic        full;

    logic        rd_en;
    logic [31:0] rd_data;
    logic        empty;

    logic [31:0] write_counter_q;
    logic [31:0] expected_counter_q;
    logic        read_accepted_q;
    logic        pass_q;
    logic        error_q;
    logic [23:0] heartbeat_q;

    clk_wiz_0 clock_generator (
        .clk_out1 (clk_slow),
        .clk_out2 (clk_fast),
        .reset    (btnC),
        .locked   (clocks_locked),
        .clk_in1  (clk)
    );

    assign reset_async = btnC || !clocks_locked;

    always_ff @(posedge clk_slow or posedge reset_async) begin
        if (reset_async) begin
            slow_reset_sync_q <= 2'b00;
        end else begin
            slow_reset_sync_q <= {slow_reset_sync_q[0], 1'b1};
        end
    end

    always_ff @(posedge clk_fast or posedge reset_async) begin
        if (reset_async) begin
            fast_reset_sync_q <= 2'b00;
        end else begin
            fast_reset_sync_q <= {fast_reset_sync_q[0], 1'b1};
        end
    end

    assign slow_rst_ni = slow_reset_sync_q[1];
    assign fast_rst_ni = fast_reset_sync_q[1];

    assign wr_en   = slow_rst_ni && !full;
    assign wr_data = write_counter_q;
    assign rd_en   = fast_rst_ni && !empty;

    async_fifo #(
        .DATA_WIDTH (32),
        .DEPTH      (16)
    ) fifo (
        .wr_clk_i  (clk_slow),
        .wr_rst_ni (slow_rst_ni),
        .wr_en_i   (wr_en),
        .wr_data_i (wr_data),
        .full_o    (full),
        .rd_clk_i  (clk_fast),
        .rd_rst_ni (fast_rst_ni),
        .rd_en_i   (rd_en),
        .rd_data_o (rd_data),
        .empty_o   (empty)
    );

    always_ff @(posedge clk_slow or negedge slow_rst_ni) begin
        if (!slow_rst_ni) begin
            write_counter_q <= 32'd0;
            heartbeat_q     <= 24'd0;
        end else begin
            heartbeat_q <= heartbeat_q + 1'b1;

            if (wr_en && !full) begin
                write_counter_q <= write_counter_q + 1'b1;
            end
        end
    end

    always_ff @(posedge clk_fast or negedge fast_rst_ni) begin
        if (!fast_rst_ni) begin
            expected_counter_q <= 32'd0;
            read_accepted_q    <= 1'b0;
            pass_q             <= 1'b0;
            error_q            <= 1'b0;
        end else begin
            read_accepted_q <= rd_en && !empty;

            if (read_accepted_q) begin
                if (rd_data != expected_counter_q) begin
                    error_q <= 1'b1;
                end else if (expected_counter_q == 32'd255 && !error_q) begin
                    pass_q <= 1'b1;
                end

                expected_counter_q <= expected_counter_q + 1'b1;
            end
        end
    end

    assign led = {
        10'b0,
        clocks_locked,
        error_q,
        pass_q,
        full,
        !empty,
        heartbeat_q[23]
    };

endmodule
