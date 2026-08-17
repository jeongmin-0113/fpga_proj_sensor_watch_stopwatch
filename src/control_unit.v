`timescale 1ns / 1ps

// Project-level control unit. It translates decoded UART commands and board
// buttons into datapath controls, sequences sensor reads, and requests replies.
module system_control_unit (
    input        clk,
    input        reset,

    input        i_cmd_done,
    input        i_cmd_op,
    input        i_cmd_error,
    input  [9:0] i_cmd_signals,
    input  [3:0] i_cmd_target,

    input  [1:0] i_mode_select,
    input        i_btn_left,
    input        i_btn_right,
    input        i_btn_up,
    input        i_btn_down,

    input        i_stopwatch_saved,
    input        i_sr04_ready,
    input        i_sr04_done,
    input        i_sr04_error,
    input        i_dht11_ready,
    input        i_dht11_done,
    input        i_dht11_valid,

    input        i_response_ready,

    output reg   o_stopwatch_run,
    output reg   o_stopwatch_clear,
    output reg   o_stopwatch_mode,
    output reg   o_stopwatch_save,
    output reg   o_stopwatch_load,

    output reg   o_watch_up,
    output reg   o_watch_down,
    output reg   o_watch_left,
    output reg   o_watch_right,

    output reg   o_sr04_start,
    output reg   o_dht11_start,

    output reg       o_response_valid,
    output reg [2:0] o_response_kind,
    output           o_busy
);
    localparam [1:0] CONTROL_IDLE = 2'd0;
    localparam [1:0] WAIT_SR04    = 2'd1;
    localparam [1:0] WAIT_DHT11   = 2'd2;

    localparam [2:0] RESP_ACK   = 3'd0;
    localparam [2:0] RESP_ERROR = 3'd1;
    localparam [2:0] RESP_SW    = 3'd2;
    localparam [2:0] RESP_WATCH = 3'd3;
    localparam [2:0] RESP_DIST  = 3'd4;
    localparam [2:0] RESP_DHT11 = 3'd5;

    reg [1:0] state_reg;

    assign o_busy = (state_reg != CONTROL_IDLE) || o_response_valid;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state_reg          <= CONTROL_IDLE;
            o_stopwatch_run    <= 1'b0;
            o_stopwatch_clear  <= 1'b0;
            o_stopwatch_mode   <= 1'b0;
            o_stopwatch_save   <= 1'b0;
            o_stopwatch_load   <= 1'b0;
            o_watch_up         <= 1'b0;
            o_watch_down       <= 1'b0;
            o_watch_left       <= 1'b0;
            o_watch_right      <= 1'b0;
            o_sr04_start       <= 1'b0;
            o_dht11_start      <= 1'b0;
            o_response_valid   <= 1'b0;
            o_response_kind    <= RESP_ACK;
        end else begin
            // Pulse-type outputs default low every clock.
            o_stopwatch_clear <= 1'b0;
            o_stopwatch_save  <= 1'b0;
            o_stopwatch_load  <= 1'b0;
            o_watch_up        <= 1'b0;
            o_watch_down      <= 1'b0;
            o_watch_left      <= 1'b0;
            o_watch_right     <= 1'b0;
            o_sr04_start      <= 1'b0;
            o_dht11_start     <= 1'b0;

            if (o_response_valid && i_response_ready)
                o_response_valid <= 1'b0;

            // Context-sensitive board controls.
            case (i_mode_select)
                2'b00: begin
                    if (i_btn_left)
                        o_stopwatch_run <= ~o_stopwatch_run;
                    if (i_btn_right)
                        o_stopwatch_clear <= 1'b1;
                    if (i_btn_up)
                        o_stopwatch_mode <= ~o_stopwatch_mode;
                    if (i_btn_down) begin
                        if (i_stopwatch_saved)
                            o_stopwatch_load <= 1'b1;
                        else
                            o_stopwatch_save <= 1'b1;
                    end
                end
                2'b01: begin
                    o_watch_left  <= i_btn_left;
                    o_watch_right <= i_btn_right;
                    o_watch_up    <= i_btn_up;
                    o_watch_down  <= i_btn_down;
                end
                2'b10: begin
                    if (i_btn_down && i_sr04_ready)
                        o_sr04_start <= 1'b1;
                end
                2'b11: begin
                    if (i_btn_down && i_dht11_ready)
                        o_dht11_start <= 1'b1;
                end
            endcase

            case (state_reg)
                CONTROL_IDLE: begin
                    if (i_cmd_done && !o_response_valid) begin
                        if (i_cmd_error) begin
                            o_response_kind  <= RESP_ERROR;
                            o_response_valid <= 1'b1;
                        end else if (i_cmd_op) begin
                            // Multi-byte command: only target is meaningful.
                            if (i_cmd_target[3]) begin
                                o_response_kind  <= RESP_SW;
                                o_response_valid <= 1'b1;
                            end else if (i_cmd_target[2]) begin
                                o_response_kind  <= RESP_WATCH;
                                o_response_valid <= 1'b1;
                            end else if (i_cmd_target[1]) begin
                                if (i_sr04_ready) begin
                                    o_sr04_start <= 1'b1;
                                    state_reg    <= WAIT_SR04;
                                end else begin
                                    o_response_kind  <= RESP_ERROR;
                                    o_response_valid <= 1'b1;
                                end
                            end else if (i_cmd_target[0]) begin
                                if (i_dht11_ready) begin
                                    o_dht11_start <= 1'b1;
                                    state_reg     <= WAIT_DHT11;
                                end else begin
                                    o_response_kind  <= RESP_ERROR;
                                    o_response_valid <= 1'b1;
                                end
                            end else begin
                                o_response_kind  <= RESP_ERROR;
                                o_response_valid <= 1'b1;
                            end
                        end else begin
                            // One-byte command: only signals is meaningful.
                            if (|i_cmd_signals) begin
                                if (i_cmd_signals[9]) o_stopwatch_run <= 1'b1;
                                if (i_cmd_signals[8]) o_stopwatch_run <= 1'b0;
                                if (i_cmd_signals[7]) o_stopwatch_clear <= 1'b1;
                                if (i_cmd_signals[6]) o_stopwatch_mode <= ~o_stopwatch_mode;
                                if (i_cmd_signals[5] && !i_stopwatch_saved)
                                    o_stopwatch_save <= 1'b1;
                                if (i_cmd_signals[4] && i_stopwatch_saved)
                                    o_stopwatch_load <= 1'b1;
                                if (i_cmd_signals[3]) o_watch_up <= 1'b1;
                                if (i_cmd_signals[2]) o_watch_down <= 1'b1;
                                if (i_cmd_signals[1]) o_watch_left <= 1'b1;
                                if (i_cmd_signals[0]) o_watch_right <= 1'b1;
                                o_response_kind  <= RESP_ACK;
                                o_response_valid <= 1'b1;
                            end else begin
                                o_response_kind  <= RESP_ERROR;
                                o_response_valid <= 1'b1;
                            end
                        end
                    end
                end

                WAIT_SR04: begin
                    if (i_sr04_error) begin
                        state_reg          <= CONTROL_IDLE;
                        o_response_kind    <= RESP_ERROR;
                        o_response_valid   <= 1'b1;
                    end else if (i_sr04_done) begin
                        state_reg          <= CONTROL_IDLE;
                        o_response_kind    <= RESP_DIST;
                        o_response_valid   <= 1'b1;
                    end
                end

                WAIT_DHT11: begin
                    if (i_dht11_done) begin
                        state_reg        <= CONTROL_IDLE;
                        o_response_kind  <= i_dht11_valid ? RESP_DHT11 : RESP_ERROR;
                        o_response_valid <= 1'b1;
                    end
                end

                default: state_reg <= CONTROL_IDLE;
            endcase
        end
    end
endmodule
