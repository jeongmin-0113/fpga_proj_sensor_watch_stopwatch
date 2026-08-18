`timescale 1ns / 1ps

module stopwatch_datapath #(
    parameter MSEC_WIDTH = 7,
    SEC_WIDTH = 6,
    MIN_WIDTH = 6,
    HOUR_WIDTH = 5
) (
    input                       clk,
    input                       reset,
    input                       runstop,
    input                       clear,
    input                       mode,
    input                       save,
    input                       load,
    output reg                  o_is_data_saved,
    output     [MSEC_WIDTH-1:0] m_sec,
    output     [ SEC_WIDTH-1:0] sec,
    output     [ MIN_WIDTH-1:0] min,
    output     [HOUR_WIDTH-1:0] hour
);

    wire w_tick_msec, w_tick_sec, w_tick_min, w_tick_hour;

    // f/f에 저장된 시간 데이터
    reg [MSEC_WIDTH-1:0] w_saved_msec;
    reg [ SEC_WIDTH-1:0] w_saved_sec;
    reg [ MIN_WIDTH-1:0] w_saved_min;
    reg [HOUR_WIDTH-1:0] w_saved_hour;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            w_saved_msec <= 0;
            w_saved_sec <= 0;
            w_saved_min <= 0;
            w_saved_hour <= 0;
            o_is_data_saved <= 0;
        end else begin
            if (save) begin
                w_saved_msec <= m_sec;
                w_saved_sec <= sec;
                w_saved_min <= min;
                w_saved_hour <= hour;
                o_is_data_saved <= 1;
            end
            if (load) begin
                o_is_data_saved <= 0;
            end
        end
    end

    tick_gen_100Hz GEN_100HZ (
        .clk(clk),
        .reset(reset),
        .o_tick(w_tick_msec)
    );

    stopwatch_time_counter #(
        .COUNT_NUM(100)
    ) U_COUNTER_MSEC (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_msec),
        .mode(mode),
        .run_stop(runstop),
        .clear(clear),
        .load(load),
        .value(w_saved_msec),
        .time_cnt(m_sec),
        .o_tick(w_tick_sec)
    );

    stopwatch_time_counter #(
        .COUNT_NUM(60)
    ) U_COUNTER_SEC (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_sec),
        .mode(mode),
        .run_stop(runstop),
        .clear(clear),
        .load(load),
        .value(w_saved_sec),
        .time_cnt(sec),
        .o_tick(w_tick_min)
    );

    stopwatch_time_counter #(
        .COUNT_NUM(60)
    ) U_COUNTER_MIN (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_min),
        .mode(mode),
        .run_stop(runstop),
        .clear(clear),
        .load(load),
        .value(w_saved_min),
        .time_cnt(min),
        .o_tick(w_tick_hour)
    );

    stopwatch_time_counter #(
        .COUNT_NUM(24)
    ) U_COUNTER_HOUR (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_hour),
        .mode(mode),
        .run_stop(runstop),
        .clear(clear),
        .load(load),
        .value(w_saved_hour),
        .time_cnt(hour),
        .o_tick()
    );

endmodule

module stopwatch_time_counter #(
    parameter COUNT_NUM = 100
) (
    input clk,
    input reset,
    input i_tick,
    input mode,
    input run_stop,
    input clear,
    input load,
    input [$clog2(COUNT_NUM)-1:0] value,
    output reg [$clog2(COUNT_NUM)-1:0] time_cnt,
    output reg o_tick
);

    always @(posedge clk, posedge reset) begin
        if (reset | clear) begin
            time_cnt <= 0;
            o_tick   <= 1'b0;
        end else begin
            if (i_tick & run_stop) begin
                if (!mode) begin
                    time_cnt <= time_cnt + 1;
                    if (time_cnt == COUNT_NUM - 1) begin
                        time_cnt <= 0;
                        o_tick   <= 1'b1;
                    end
                end else begin
                    time_cnt <= time_cnt - 1;
                    if (time_cnt == 0) begin
                        time_cnt <= COUNT_NUM - 1;
                        o_tick   <= 1'b1;
                    end
                end
            end else begin
                o_tick <= 1'b0;
            end
            if (load) time_cnt <= value;
        end
    end

endmodule


// module tick_gen_100hz (
//     input clk,
//     input reset,
//     output reg o_tick
// );

//     parameter F_COUNT = 1_000_000;
//     //parameter F_COUNT = 1000;
//     reg [$clog2(F_COUNT)-1:0] counter_reg;

//     always @(posedge clk, posedge reset) begin
//         if (reset) begin
//             counter_reg <= 0;
//             o_tick <= 1'b0;
//         end else begin
//             if (counter_reg == F_COUNT - 1) begin
//                 counter_reg <= 0;
//                 o_tick <= 1'b1;
//             end else begin
//                 counter_reg <= counter_reg + 1;
//                 o_tick <= 1'b0;
//             end
//         end
//     end

// endmodule

