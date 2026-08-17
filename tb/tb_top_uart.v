`timescale 1ns / 1ps

// Contract-preserving UART RX integration test. The teammate-owned decoder is
// used without modification; its current public action commands are one byte.
module tb_top_uart;
    localparam integer CLK_FREQ_HZ = 10_000_000;
    localparam integer BAUD_RATE   = 100_000;
    localparam integer CLK_NS      = 100;
    localparam integer BIT_NS      =
        (CLK_FREQ_HZ / (BAUD_RATE * 16)) * 16 * CLK_NS;

    reg clk, reset, rx;
    reg btn_L, btn_R, btn_UP, btn_DOWN;
    reg [2:0] sw;
    reg sr04_echo;
    wire tx, sr04_trigger, dht11_io;
    wire [3:0] fnd_com, led;
    wire [7:0] fnd_data;
    integer failures;

    top #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk), .reset(reset), .rx(rx), .tx(tx),
        .btn_L(btn_L), .btn_R(btn_R), .btn_UP(btn_UP), .btn_DOWN(btn_DOWN),
        .sw(sw), .sr04_echo(sr04_echo), .sr04_trigger(sr04_trigger),
        .dht11_io(dht11_io), .fnd_com(fnd_com), .fnd_data(fnd_data), .led(led)
    );

    always #(CLK_NS / 2) clk = ~clk;

    initial begin
        #5_000_000;
        $fatal(1, "TOP UART RX INTEGRATION TEST WATCHDOG TIMEOUT");
    end

`ifdef DUMP_VCD
    initial begin
        $dumpfile("tb_top_uart.vcd");
        $dumpvars(0, clk, reset, rx, tx, led, dut.uart_rx_data,
                  dut.uart_rx_empty, dut.uart_rx_pop, dut.cmd_done, dut.cmd_op,
                  dut.cmd_signals, dut.stopwatch_run,
                  dut.response_valid, dut.response_kind);
    end
`endif

    task uart_send_byte;
        input [7:0] value;
        integer bit_index;
        begin
            rx = 1'b0;
            #(BIT_NS);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                rx = value[bit_index];
                #(BIT_NS);
            end
            rx = 1'b1;
            #(BIT_NS);
        end
    endtask

    task wait_run_state;
        input expected;
        integer cycles;
        begin
            cycles = 0;
            while (dut.stopwatch_run !== expected && cycles < 500) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            if (dut.stopwatch_run !== expected) begin
                $display("FAIL: stopwatch_run=%b expected=%b", dut.stopwatch_run, expected);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        clk = 0; reset = 1; rx = 1;
        btn_L = 0; btn_R = 0; btn_UP = 0; btn_DOWN = 0;
        sw = 0; sr04_echo = 0; failures = 0;
        repeat (8) @(negedge clk);
        reset = 0;

        // Current decoder contract: 'r' starts and 's' stops the stopwatch.
        uart_send_byte("r");
        wait_run_state(1'b1);
        uart_send_byte("s");
        wait_run_state(1'b0);

        // TX formatting remains owned by the pending teammate encoder.
        if (tx !== 1'b1) begin
            $display("FAIL: TX must remain idle until ASCII encoder integration");
            failures = failures + 1;
        end

        if (failures == 0)
            $display("TOP UART RX INTEGRATION TEST PASS");
        else
            $fatal(1, "TOP UART RX INTEGRATION TEST FAIL: %0d", failures);
        $finish;
    end
endmodule
