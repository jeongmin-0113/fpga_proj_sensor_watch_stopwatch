`timescale 1ns / 1ps

module ascii_decoder (
    input        clk,
    input        reset,
    input        i_fifo_empty,
    input  [7:0] i_data,
    output       o_get,
    output       o_op,
    output [9:0] o_signals,
    output [3:0] o_target,
    output       o_done
);

    localparam [2:0] IDLE = 0;
    localparam [2:0] COMMAND = 1;
    localparam [2:0] TARGET = 2;
    localparam [2:0] DONE = 3;
    localparam [2:0] ERROR = 4;

    reg [2:0] c_state, n_state;

    reg [79:0] command_reg, command_next;

    reg op_reg, op_next;
    reg done_reg, done_next;

    assign o_op = op_reg;
    assign o_done = done_reg;

    assign o_get= (c_state != DONE)  && !i_fifo_empty;

    // reg [7:0] data_reg, data_next;
    reg [9:0] signal_next, signal_reg;
    reg [3:0] target_next, target_reg;

    assign o_signals = signal_reg;
    assign o_target  = target_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state     <= IDLE;
            command_reg <= 0;
            op_reg      <= 0;
            done_reg    <= 0;
            // data_reg <= 0;
            signal_reg  <= 0;
            target_reg  <= 0;
        end else begin
            c_state     <= n_state;
            command_reg <= command_next;
            op_reg      <= op_next;
            done_reg    <= done_next;
            // data_reg <= data_next;
            signal_reg  <= signal_next;
            target_reg  <= target_next;
        end
    end

    always @(*) begin
        n_state      = c_state;
        command_next = command_reg;
        op_next      = op_reg;
        done_next    = done_reg;
        target_next  = target_reg;
        signal_next  = signal_reg;
        case (c_state)
            IDLE: begin
                //command_next = 0;
                done_next = 0;
                if (o_get) begin
                    command_next = {72'd0, i_data};
                    target_next  = 0;
                    signal_next  = 0;
                    if (i_data == "/") begin
                        op_next = 1;
                        n_state = COMMAND;
                    end else begin
                        op_next = 0;
                        n_state = DONE;
                    end
                end
            end
            COMMAND: begin
                if (o_get) begin
                    if (i_data == " ") begin
                        if (command_reg == "/get") begin
                            n_state = TARGET;
                            command_next = 0;
                        end else begin
                            n_state = ERROR;
                            command_next = 0;
                        end
                    end else begin
                        command_next = {command_reg[71:0], i_data};
                    end
                end
            end
            TARGET: begin
                if (o_get) begin
                    if ((i_data == ".")) begin
                        n_state = DONE;
                    end else begin
                        command_next = {command_reg[71:0], i_data};
                    end
                end
            end
            DONE: begin
                case (command_reg)
                    // op == 0, 1 byte 명령
                    "r": signal_next[9] = 1'b1;
                    "s": signal_next[8] = 1'b1;
                    "c": signal_next[7] = 1'b1;
                    "m": signal_next[6] = 1'b1;
                    "0": signal_next[5] = 1'b1;
                    "1": signal_next[4] = 1'b1;
                    "U": signal_next[3] = 1'b1;
                    "D": signal_next[2] = 1'b1;
                    "L": signal_next[1] = 1'b1;
                    "R": signal_next[0] = 1'b1;

                    // op == 1, 멀티바이트 명령 (get)
                    "sw_time": target_next[3] = 1'b1;
                    "time": target_next[2] = 1'b1;
                    "dist": target_next[1] = 1'b1;
                    "temp_hum": target_next[0] = 1'b1;
                endcase
                command_next = 0;
                n_state = IDLE;
                done_next = 1;
            end
            ERROR: begin
                if (o_get) begin
                    if (i_data == 8'h0A) begin
                        n_state = IDLE;
                    end
                end
            end
        endcase
    end
endmodule
