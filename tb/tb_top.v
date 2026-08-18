`timescale 1ns / 1ps

module tb_top ();

    parameter BAUD_TICK = 100_000_000 / 9600 * 10;

    reg clk, reset;
    reg  rx;
    wire tx;
    reg btn_L, btn_R, btn_UP, btn_DOWN;
    reg [2:0] sw;

    reg sr04_echo;
    wire sr04_trigger;
    wire dht11_io;

    wire [3:0] fnd_com;
    wire [7:0] fnd_data;
    wire [3:0] led;

    top dut (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .tx(tx),

        .btn_L(btn_L),
        .btn_R(btn_R),
        .btn_UP(btn_UP),
        .btn_DOWN(btn_DOWN),
        .sw(sw),

        .sr04_echo(sr04_echo),
        .sr04_trigger(sr04_trigger),
        .dht11_io(dht11_io),

        .fnd_com(fnd_com),
        .fnd_data(fnd_data),
        .led(led)
    );

    integer i;
    task PC_SENDER_TASK(input [7:0] i_data);
        begin
            rx = 0;
            #BAUD_TICK;
            for (i = 0; i < 8; i = i + 1) begin
                rx = i_data[i];
                #BAUD_TICK;
            end
            rx = 1;
            #BAUD_TICK;
        end
    endtask

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        rx = 1;
        {btn_L, btn_R, btn_DOWN, btn_UP} = 4'b0;
        sw = 3'b010;
        sr04_echo = 0;
        #10;
        reset = 0;

        PC_SENDER_TASK("/");
        PC_SENDER_TASK("g");
        PC_SENDER_TASK("e");
        PC_SENDER_TASK("t");
        PC_SENDER_TASK(" ");
        PC_SENDER_TASK("d");
        PC_SENDER_TASK("i");
        PC_SENDER_TASK("s");
        PC_SENDER_TASK("t");
        PC_SENDER_TASK("\n");
        // PC_SENDER_TASK("s");

        $stop;
    end
endmodule
