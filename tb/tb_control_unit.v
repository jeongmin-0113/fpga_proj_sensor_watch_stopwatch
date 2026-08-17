`timescale 1ns / 1ps

module tb_control_unit;
    reg clk, reset;
    reg cmd_done, cmd_op, cmd_error;
    reg [9:0] cmd_signals;
    reg [3:0] cmd_target;
    reg [1:0] mode_select;
    reg btn_left, btn_right, btn_up, btn_down;
    reg stopwatch_saved;
    reg sr04_ready, sr04_done, sr04_error;
    reg dht11_ready, dht11_done, dht11_valid;
    reg response_ready;

    wire stopwatch_run, stopwatch_clear, stopwatch_mode;
    wire stopwatch_save, stopwatch_load;
    wire watch_up, watch_down, watch_left, watch_right;
    wire sr04_start, dht11_start;
    wire response_valid;
    wire [2:0] response_kind;
    wire busy;
    integer failures;

    system_control_unit dut (
        .clk(clk), .reset(reset),
        .i_cmd_done(cmd_done), .i_cmd_op(cmd_op), .i_cmd_error(cmd_error),
        .i_cmd_signals(cmd_signals), .i_cmd_target(cmd_target),
        .i_mode_select(mode_select),
        .i_btn_left(btn_left), .i_btn_right(btn_right),
        .i_btn_up(btn_up), .i_btn_down(btn_down),
        .i_stopwatch_saved(stopwatch_saved),
        .i_sr04_ready(sr04_ready), .i_sr04_done(sr04_done),
        .i_sr04_error(sr04_error), .i_dht11_ready(dht11_ready),
        .i_dht11_done(dht11_done), .i_dht11_valid(dht11_valid),
        .i_response_ready(response_ready),
        .o_stopwatch_run(stopwatch_run), .o_stopwatch_clear(stopwatch_clear),
        .o_stopwatch_mode(stopwatch_mode), .o_stopwatch_save(stopwatch_save),
        .o_stopwatch_load(stopwatch_load), .o_watch_up(watch_up),
        .o_watch_down(watch_down), .o_watch_left(watch_left),
        .o_watch_right(watch_right), .o_sr04_start(sr04_start),
        .o_dht11_start(dht11_start), .o_response_valid(response_valid),
        .o_response_kind(response_kind), .o_busy(busy)
    );

    always #5 clk = ~clk;

    initial begin
        #100_000;
        $fatal(1, "CONTROL UNIT TEST WATCHDOG TIMEOUT");
    end

`ifdef DUMP_VCD
    initial begin
        $dumpfile("tb_control_unit.vcd");
        $dumpvars(0, clk, reset, cmd_done, cmd_op, cmd_error, cmd_signals,
                  cmd_target, mode_select, sr04_ready, sr04_done,
                  sr04_error, dht11_ready, dht11_done, dht11_valid,
                  stopwatch_run, stopwatch_clear, stopwatch_mode,
                  stopwatch_save, stopwatch_load, watch_up, watch_down,
                  watch_left, watch_right, sr04_start, dht11_start,
                  response_valid, response_kind, busy, dut.state_reg);
    end
`endif

    task command;
        input op_in;
        input [9:0] signals_in;
        input [3:0] target_in;
        input error_in;
        begin
            @(negedge clk);
            cmd_op = op_in;
            cmd_signals = signals_in;
            cmd_target = target_in;
            cmd_error = error_in;
            cmd_done = 1'b1;
            @(negedge clk);
            cmd_done = 1'b0;
            cmd_op = 1'b0;
            cmd_signals = 0;
            cmd_target = 0;
            cmd_error = 0;
        end
    endtask

    task consume_response;
        input [2:0] expected_kind;
        begin
            #1;
            if (!response_valid || response_kind !== expected_kind) begin
                $display("FAIL response valid=%b kind=%0d expected=%0d",
                         response_valid, response_kind, expected_kind);
                failures = failures + 1;
            end
            @(negedge clk);
            response_ready = 1'b1;
            @(negedge clk);
            response_ready = 1'b0;
        end
    endtask

    initial begin
        clk = 0; reset = 1;
        cmd_done = 0; cmd_op = 0; cmd_error = 0;
        cmd_signals = 0; cmd_target = 0;
        mode_select = 0;
        btn_left = 0; btn_right = 0; btn_up = 0; btn_down = 0;
        stopwatch_saved = 0;
        sr04_ready = 1; sr04_done = 0; sr04_error = 0;
        dht11_ready = 1; dht11_done = 0; dht11_valid = 0;
        response_ready = 0;
        failures = 0;
        repeat (2) @(negedge clk);
        reset = 0;

        // Decoded run action
        command(0, 10'b10_0000_0000, 4'b1000, 0);
        if (!stopwatch_run) begin
            $display("FAIL: stopwatch did not run");
            failures = failures + 1;
        end
        repeat (3) @(negedge clk);
        if (!response_valid || response_kind != 3'd0) begin
            $display("FAIL: response did not hold under backpressure");
            failures = failures + 1;
        end
        consume_response(3'd0);

        // /get_stop and pulse commands.
        command(0, 10'b01_0000_0000, 0, 0);
        if (stopwatch_run) failures = failures + 1;
        consume_response(3'd0);

        command(0, 10'b00_1000_0000, 0, 0);
        if (!stopwatch_clear) failures = failures + 1;
        consume_response(3'd0);

        command(0, 10'b00_0100_0000, 0, 0);
        if (!stopwatch_mode) failures = failures + 1;
        consume_response(3'd0);

        command(0, 10'b00_0010_0000, 0, 0);
        if (!stopwatch_save) failures = failures + 1;
        consume_response(3'd0);
        stopwatch_saved = 1;
        command(0, 10'b00_0001_0000, 0, 0);
        if (!stopwatch_load) failures = failures + 1;
        consume_response(3'd0);

        // Decoded distance query launches SR04 and waits for completion.
        command(1, 10'b01_0000_0000, 4'b0010, 0);
        #1;
        if (!sr04_start || response_valid) begin
            $display("FAIL: SR04 query sequencing");
            failures = failures + 1;
        end
        @(negedge clk);
        sr04_done = 1;
        @(negedge clk);
        sr04_done = 0;
        consume_response(3'd4);

        // SR04 error and not-ready paths return ERR.
        wait (!response_valid);
        command(1, 0, 4'b0010, 0);
        @(negedge clk); sr04_error = 1;
        @(negedge clk); sr04_error = 0;
        consume_response(3'd1);
        sr04_ready = 0;
        command(1, 0, 4'b0010, 0);
        consume_response(3'd1);
        sr04_ready = 1;

        // DHT11 query returns data only for a valid frame.
        command(1, 0, 4'b0001, 0);
        if (!dht11_start) failures = failures + 1;
        @(negedge clk); dht11_valid = 1; dht11_done = 1;
        @(negedge clk); dht11_done = 0;
        consume_response(3'd5);
        command(1, 0, 4'b0001, 0);
        @(negedge clk); dht11_valid = 0; dht11_done = 1;
        @(negedge clk); dht11_done = 0;
        consume_response(3'd1);

        // Invalid decoder result returns ERR.
        command(0, 0, 0, 1);
        consume_response(3'd1);

        // op=1 must not interpret a stale one-byte signal vector.
        command(1, 10'b10_0000_0000, 0, 0);
        consume_response(3'd1);

        // Watch buttons are routed only in watch display mode.
        mode_select = 2'b01;
        @(negedge clk); btn_up = 1;
        @(negedge clk); btn_up = 0;
        #1;
        if (!watch_up) begin
            $display("FAIL: watch button routing");
            failures = failures + 1;
        end

        // Sensor-mode board button starts only the selected sensor.
        mode_select = 2'b10;
        @(negedge clk); btn_down = 1;
        @(negedge clk); btn_down = 0;
        if (!sr04_start || dht11_start) failures = failures + 1;
        mode_select = 2'b11;
        @(negedge clk); btn_down = 1;
        @(negedge clk); btn_down = 0;
        if (!dht11_start || sr04_start) failures = failures + 1;

        if (failures == 0)
            $display("CONTROL UNIT TEST PASS");
        else
            $fatal(1, "CONTROL UNIT TEST FAIL: %0d failure(s)", failures);
        $finish;
    end
endmodule
