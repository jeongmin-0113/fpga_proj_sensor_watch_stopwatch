`timescale 1ns / 1ps

module ascii_encoder (
    input clk,
    input reset,
    input i_start,
    input [2:0] i_source,  // 2: stopwatch / 3: watch / 4: sr04 / 5:dht11
    input [8:0] i_data0,  // 0: hour / 1: hour / 2: distance / 3: temperature - int
    input [6:0] i_data1,  // 0: min  / 1: min  / 2: -        / 3: temperature - de
    input [6:0] i_data2,  // 0: sec  / 1: sec  / 2: -        / 3: humidity - int
    input [6:0] i_data3,  // 0: msec / 1: msec / 2: -        / 3: humidity - de
    input i_fifo_full,
    output o_fifo_push,
    output [7:0] o_data,
    output o_encoder_free
);

    localparam IDLE = 0;
    localparam SEND = 1;

    reg c_state, n_state;

    wire [8*30-1:0] format_buf;
    reg [8*30-1:0] buf_reg, buf_next;

    assign o_fifo_push = (c_state == SEND) && !i_fifo_full && (buf_reg != 00);
    assign o_data = buf_reg[239:232];
    assign o_encoder_free = (c_state == IDLE);


    ascii_formatter U_FORMATTER (
        .i_source(i_source),  // 2: stopwatch / 3: watch / 4: sr04 / 5:dht11
        .i_data0(i_data0),  // 0: hour / 1: hour / 2: distance / 3: temperature - int
        .i_data1(i_data1),  // 0: min  / 1: min  / 2: -        / 3: temperature - de
        .i_data2(i_data2),  // 0: sec  / 1: sec  / 2: -        / 3: humidity - int
        .i_data3(i_data3),  // 0: msec / 1: msec / 2: -        / 3: humidity - de
        .format_buf(format_buf)
    );

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= IDLE;
            buf_reg <= 0;
        end else begin
            c_state <= n_state;
            buf_reg <= buf_next;
        end
    end

    always @(*) begin
        n_state  = c_state;
        buf_next = buf_reg;
        case (c_state)
            IDLE: begin
                if (i_start) begin
                    n_state  = SEND;
                    buf_next = format_buf;
                end
            end
            SEND: begin
                if (!i_fifo_full) begin
                    if (buf_reg == 0) begin
                        n_state = IDLE;
                    end else begin
                        buf_next = {buf_reg[231:0], 8'h00};
                    end
                end
            end
        endcase
    end



endmodule

module ascii_formatter (
    input [2:0] i_source,  // 2: stopwatch / 3: watch / 4: sr04 / 5:dht11
    input [8:0] i_data0,  // 0: hour / 1: hour / 2: distance / 3: temperature - int
    input [6:0] i_data1,  // 0: min  / 1: min  / 2: -        / 3: temperature - de
    input [6:0] i_data2,  // 0: sec  / 1: sec  / 2: -        / 3: humidity - int
    input [6:0] i_data3,  // 0: msec / 1: msec / 2: -        / 3: humidity - de
    output reg [8*30-1:0] format_buf
);
    localparam [2:0] STOPWATCH = 2;
    localparam [2:0] WATCH = 3;
    localparam [2:0] SR04 = 4;
    localparam [2:0] DHT11 = 5;

    wire [7:0] i_data0_100, i_data0_10, i_data0_1;
    wire [7:0] i_data1_10, i_data1_1;
    wire [7:0] i_data2_10, i_data2_1;
    wire [7:0] i_data3_10, i_data3_1;

    assign i_data0_100 = (i_data0 / 100) % 10 + "0";
    assign i_data0_10  = (i_data0 / 10) % 10 + "0";
    assign i_data0_1   = i_data0 % 10 + "0";

    assign i_data1_10  = (i_data1 / 10) % 10 + "0";
    assign i_data1_1   = i_data1 % 10 + "0";

    assign i_data2_10  = (i_data2 / 10) % 10 + "0";
    assign i_data2_1   = i_data2 % 10 + "0";

    assign i_data3_10  = (i_data3 / 10) % 10 + "0";
    assign i_data3_1   = i_data3 % 10 + "0";

    always @(*) begin
        format_buf = 0;
        case (i_source)
            STOPWATCH: begin
                format_buf = {
                    "(STOPWATCH): ",
                    i_data0_10,
                    i_data0_1,
                    ":",
                    i_data1_10,
                    i_data1_1,
                    ":",
                    i_data2_10,
                    i_data2_1,
                    ":",
                    i_data3_10,
                    i_data3_1,
                    "\n",
                    {5{8'h0}}
                };
            end
            WATCH: begin
                format_buf = {
                    "(WATCH): ",
                    i_data0_10,
                    i_data0_1,
                    ":",
                    i_data1_10,
                    i_data1_1,
                    ":",
                    i_data2_10,
                    i_data2_1,
                    ":",
                    i_data3_10,
                    i_data3_1,
                    "\n",
                    {9{8'h0}}
                };
            end
            SR04: begin
                format_buf = {
                    i_data0_100, i_data0_10, i_data0_1, "cm", "\n", {24{8'h0}}
                };
            end
            DHT11: begin
                format_buf = {
                    i_data0_10,
                    i_data0_1,
                    ".",
                    i_data1_10,
                    i_data1_1,
                    "'C ",
                    i_data2_10,
                    i_data2_1,
                    ".",
                    i_data3_10,
                    i_data3_1,
                    "%",
                    "\n",
                    {15{8'h0}}
                };
            end
            default: begin
                format_buf = 0;
            end
        endcase
    end

endmodule
