`timescale 1ns / 1ps

// Integrated top: UART/FIFO + stopwatch + watch + SR04 + DHT11.
// sw[1:0] selects the display: 00 stopwatch, 01 watch, 10 SR04, 11 DHT11.
// sw[2] selects the alternate display page.
module top #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 9_600
) (
    input  clk,
    input  reset,
    input  rx,
    output tx,

    input       btn_L,
    input       btn_R,
    input       btn_UP,
    input       btn_DOWN,
    input [2:0] sw,

    input  sr04_echo,
    output sr04_trigger,
    inout  dht11_io,

    output [3:0] fnd_com,
    output [7:0] fnd_data,
    output [3:0] led
);
    wire btn_left;
    wire btn_right;
    wire btn_up;
    wire btn_down;

    wire [7:0] uart_rx_data;
    wire uart_rx_empty;
    wire uart_rx_pop;
    wire uart_rx_overflow;
    wire cmd_op;
    wire [9:0] cmd_signals;
    wire [3:0] cmd_target;
    wire cmd_done;
    wire cmd_error;

    wire stopwatch_run;
    wire stopwatch_clear;
    wire stopwatch_mode;
    wire stopwatch_save;
    wire stopwatch_load;
    wire stopwatch_saved;

    wire watch_up;
    wire watch_down;
    wire watch_left;
    wire watch_right;

    wire sr04_start;
    wire sr04_done;
    wire sr04_ready;
    wire sr04_error;
    wire [8:0] distance;

    wire dht11_start;
    wire dht11_done;
    wire dht11_valid;
    wire dht11_ready;
    wire [15:0] temperature;
    wire [15:0] humidity;

    wire w_baud_tick_x16;
    wire response_valid;
    wire [2:0] response_kind;
    wire response_ready;
    wire control_busy;

    wire [6:0] sw_msec;
    wire [5:0] sw_sec;
    wire [5:0] sw_min;
    wire [4:0] sw_hour;

    wire [6:0] watch_msec;
    wire [5:0] watch_sec;
    wire [5:0] watch_min;
    wire [4:0] watch_hour;
    wire [2:0] watch_position;

    reg [13:0] display_value;
    reg [3:0] decimal_mask;

    assign cmd_error = 1'b0;
    assign led[0] = stopwatch_run;
    assign led[1] = sr04_ready;
    assign led[2] = dht11_ready;
    assign led[3] = control_busy | uart_rx_overflow;

    btn_debouncer U_BTN_LEFT (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_L),
        .o_btn(btn_left)
    );
    btn_debouncer U_BTN_RIGHT (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_R),
        .o_btn(btn_right)
    );
    btn_debouncer U_BTN_UP (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_UP),
        .o_btn(btn_up)
    );
    btn_debouncer U_BTN_DOWN (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_DOWN),
        .o_btn(btn_down)
    );

    integration_uart_rx_bridge #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE),
        .FIFO_WIDTH (4)
    ) U_UART_FIFO (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .o_rx_data(uart_rx_data),
        .o_rx_empty(uart_rx_empty),
        .i_rx_pop(uart_rx_pop),
        .o_rx_overflow(uart_rx_overflow)
    );

    ascii_decoder U_ASCII_DECODER (
        .clk(clk),
        .reset(reset),
        .i_fifo_empty(uart_rx_empty),
        .i_data(uart_rx_data),
        .o_get(uart_rx_pop),
        .o_op(cmd_op),
        .o_signals(cmd_signals),
        .o_target(cmd_target),
        .o_done(cmd_done)
    );

    system_control_unit U_SYSTEM_CONTROL (
        .clk(clk),
        .reset(reset),
        .i_cmd_done(cmd_done),
        .i_cmd_op(cmd_op),
        .i_cmd_error(cmd_error),
        .i_cmd_signals(cmd_signals),
        .i_cmd_target(cmd_target),
        .i_mode_select(sw[1:0]),
        .i_btn_left(btn_left),
        .i_btn_right(btn_right),
        .i_btn_up(btn_up),
        .i_btn_down(btn_down),
        .i_stopwatch_saved(stopwatch_saved),
        .i_sr04_ready(sr04_ready),
        .i_sr04_done(sr04_done),
        .i_sr04_error(sr04_error),
        .i_dht11_ready(dht11_ready),
        .i_dht11_done(dht11_done),
        .i_dht11_valid(dht11_valid),
        .i_response_ready(response_ready),
        .o_stopwatch_run(stopwatch_run),
        .o_stopwatch_clear(stopwatch_clear),
        .o_stopwatch_mode(stopwatch_mode),
        .o_stopwatch_save(stopwatch_save),
        .o_stopwatch_load(stopwatch_load),
        .o_watch_up(watch_up),
        .o_watch_down(watch_down),
        .o_watch_left(watch_left),
        .o_watch_right(watch_right),
        .o_sr04_start(sr04_start),
        .o_dht11_start(dht11_start),
        .o_response_valid(response_valid),
        .o_response_kind(response_kind),
        .o_busy(control_busy)
    );

    reg [8:0] w_data0;
    reg [6:0] w_data1, w_data2, w_data3;
    // 4x1 mux
    // ascii encoder에 들어갈 신호를 response kind(데이터 출처) 매칭되게 연결
    always @(*) begin
        w_data0 = 0;
        w_data1 = 0;
        w_data2 = 0;
        w_data3 = 0;
        case (response_kind)
            2: begin
                w_data0 = sw_hour;
                w_data1 = sw_min;
                w_data2 = sw_sec;
                w_data3 = sw_msec;
            end
            3: begin
                w_data0 = watch_hour;
                w_data1 = watch_min;
                w_data2 = watch_sec;
                w_data3 = watch_msec;
            end
            4: begin
                w_data0 = distance;
            end
            5: begin
                w_data0 = temperature[15:8];
                w_data1 = temperature[7:0];
                w_data2 = humidity[15:8];
                w_data3 = humidity[7:0];
            end
        endcase
    end

    wire [7:0] w_encoded_data, w_fifo_popped_data;
    wire w_fifo_tx_full, w_fifo_tx_push, w_fifo_tx_empty;
    wire w_uart_tx_busy;

    // tx datapath
    // data -> ascii encoder -> fifo -> uart tx
    ascii_encoder U_ASCII_ENCODER (
        .clk(clk),
        .reset(reset),
        .i_start(response_valid),
        .i_source(response_kind),  // 0: stopwatch / 1: watch / 2: sr04 / 3:dht11
        .i_data0(w_data0),  // 0: hour / 1: hour / 2: distance / 3: temperature - int
        .i_data1(w_data1),  // 0: min  / 1: min  / 2: -        / 3: temperature - de
        .i_data2(w_data2),  // 0: sec  / 1: sec  / 2: -        / 3: humidity - int
        .i_data3(w_data3),  // 0: msec / 1: msec / 2: -        / 3: humidity - de
        .i_fifo_full(w_fifo_tx_full),
        .o_fifo_push(w_fifo_tx_push),
        .o_data(w_encoded_data),
        .o_encoder_free(response_ready)
    );


    fifo #(4) U_FIFO_TX (
        .clk  (clk),
        .reset(reset),
        .wData(w_encoded_data),
        .push (w_fifo_tx_push),
        .pop  (!w_uart_tx_busy),
        .rData(w_fifo_popped_data),
        .full (w_fifo_tx_full),
        .empty(w_fifo_tx_empty)
    );

    baud_tick_x16 #(
        .F_COUNT(CLK_FREQ_HZ / (BAUD_RATE * 16))
    ) U_BAUD_TICK_X16 (
        .clk(clk),
        .reset(reset),
        .o_baud_tick(w_baud_tick_x16)
    );

    uart_tx U_UART_TX (
        .clk(clk),
        .reset(reset),
        .i_baud_tick(w_baud_tick_x16),
        .tx_start(!w_fifo_tx_empty),
        .tx_data(w_fifo_popped_data),
        .tx(tx),
        .tx_busy(w_uart_tx_busy),
        .tx_done()
    );

    stopwatch_datapath U_STOPWATCH (
        .clk(clk),
        .reset(reset),
        .runstop(stopwatch_run),
        .clear(stopwatch_clear),
        .mode(stopwatch_mode),
        .save(stopwatch_save),
        .load(stopwatch_load),
        .o_is_data_saved(stopwatch_saved),
        .m_sec(sw_msec),
        .sec(sw_sec),
        .min(sw_min),
        .hour(sw_hour)
    );

    // data source modules
    clock U_WATCH (
        .clk(clk),
        .reset(reset),
        .btn_up(watch_up),
        .btn_down(watch_down),
        .btn_right(watch_right),
        .btn_left(watch_left),
        .msec(watch_msec),
        .sec(watch_sec),
        .min(watch_min),
        .hour(watch_hour),
        .dot_op(watch_position)
    );

    sr04_controller #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) U_SR04 (
        .clk(clk),
        .reset(reset),
        .i_start(sr04_start),
        .echo(sr04_echo),
        .trigger(sr04_trigger),
        .o_done(sr04_done),
        .o_ready(sr04_ready),
        .o_error(sr04_error),
        .distance(distance)
    );

    dht11_controller U_DHT11 (
        .clk(clk),
        .reset(reset),
        .i_start(dht11_start),
        .o_done(dht11_done),
        .o_valid(dht11_valid),
        .o_ready(dht11_ready),
        .temperature(temperature),
        .humidity(humidity),
        .dht11_io(dht11_io)
    );

    always @(*) begin
        display_value = 0;
        decimal_mask  = 0;
        case (sw[1:0])
            2'b00: begin
                if (sw[2]) display_value = sw_hour * 100 + sw_min;
                else begin
                    display_value   = sw_sec * 100 + sw_msec;
                    decimal_mask[2] = 1'b1;
                end
            end
            2'b01: begin
                if (sw[2])
                    display_value = watch_hour * 100 + watch_min;
                else begin
                    display_value = watch_sec * 100 + watch_msec;
                    decimal_mask[2] = 1'b1;
                end
            end
            2'b10: display_value = distance;
            2'b11: begin
                decimal_mask[2] = 1'b1;
                if (sw[2]) display_value = humidity[15:8] * 100 + humidity[7:0];
                else display_value = temperature[15:8] * 100 + temperature[7:0];
            end
        endcase
    end

    project_fnd_controller #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) U_PROJECT_FND (
        .clk(clk),
        .reset(reset),
        .i_value(display_value),
        .i_decimal_mask(decimal_mask),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data)
    );
endmodule
