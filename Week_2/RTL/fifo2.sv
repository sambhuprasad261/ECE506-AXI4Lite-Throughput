`timescale 1ns/1ps

// Two registered entries. A full FIFO must pop before accepting a new push.
module fifo2 #(
    parameter integer WIDTH = 8
) (
    input  logic             clk,
    input  logic             reset_n,
    input  logic             push,
    input  logic [WIDTH-1:0] in_data,
    input  logic             pop,
    output logic [WIDTH-1:0] out_data,
    output logic             empty,
    output logic             full
);
    logic [WIDTH-1:0] slots [0:1];
    logic head, tail;
    logic [1:0] count;
    logic push_fire, pop_fire;

    assign empty = (count == 0);
    assign full = (count == 2);
    assign out_data = slots[head];
    assign push_fire = push && !full;
    assign pop_fire = pop && !empty;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            head <= 0;
            tail <= 0;
            count <= 0;
            slots[0] <= '0;
            slots[1] <= '0;
        end else begin
            if (push_fire) begin
                slots[tail] <= in_data;
                tail <= !tail;
            end
            if (pop_fire)
                head <= !head;

            case ({push_fire, pop_fire})
                2'b10: count <= count + 2'd1;
                2'b01: count <= count - 2'd1;
                default: ;  // Keep occupancy when push and pop coincide.
            endcase
        end
    end
endmodule
