`timescale 1ns/1ps

module axi_lite_buffered (
    input  logic        aclk, aresetn,
    input  logic [7:0]  awaddr,
    input  logic [2:0]  awprot,
    input  logic        awvalid,
    output logic        awready,
    input  logic [31:0] wdata,
    input  logic [3:0]  wstrb,
    input  logic        wvalid,
    output logic        wready,
    output logic [1:0]  bresp,
    output logic        bvalid,
    input  logic        bready,
    input  logic [7:0]  araddr,
    input  logic [2:0]  arprot,
    input  logic        arvalid,
    output logic        arready,
    output logic [31:0] rdata,
    output logic [1:0]  rresp,
    output logic        rvalid,
    input  logic        rready
);
    localparam logic [1:0] OKAY = 2'b00, SLVERR = 2'b10;

    logic [31:0] regs [0:3];
    logic aw_empty, aw_full, w_empty, w_full, b_empty, b_full;
    logic commit_write;
    logic [7:0]  next_addr;
    logic [31:0] next_data;
    logic [3:0]  next_strb;
    logic [1:0]  next_bresp;

    // Same register map and protection policy as the Week 1 baseline.
    function automatic logic mapped(input logic [7:0] addr);
        return (addr[7:4] == 4'h0) && (addr[1:0] == 2'b00);
    endfunction

    // READY derives from registered occupancy. In particular, BREADY has
    // no combinational path to AWREADY or WREADY.
    assign awready = aresetn && !aw_full;
    assign wready  = aresetn && !w_full;
    assign bvalid  = aresetn && !b_empty;
    assign arready = aresetn && !rvalid;

    // Pop the oldest address and data together, once there is response space.
    assign commit_write = aresetn && !aw_empty && !w_empty && !b_full;
    assign next_bresp = mapped(next_addr) ? OKAY : SLVERR;

    fifo2 #(.WIDTH(8)) aw_fifo (
        .clk(aclk), .reset_n(aresetn),
        .push(awvalid && awready), .in_data(awaddr),
        .pop(commit_write), .out_data(next_addr),
        .empty(aw_empty), .full(aw_full)
    );

    fifo2 #(.WIDTH(36)) w_fifo (
        .clk(aclk), .reset_n(aresetn),
        .push(wvalid && wready), .in_data({wdata, wstrb}),
        .pop(commit_write), .out_data({next_data, next_strb}),
        .empty(w_empty), .full(w_full)
    );

    fifo2 #(.WIDTH(2)) b_fifo (
        .clk(aclk), .reset_n(aresetn),
        .push(commit_write), .in_data(next_bresp),
        .pop(bvalid && bready), .out_data(bresp),
        .empty(b_empty), .full(b_full)
    );

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (int i = 0; i < 4; i++) regs[i] <= '0;
            rvalid <= 0;
            rresp  <= OKAY;
            rdata  <= '0;
        end else begin
            if (commit_write && mapped(next_addr)) begin
                for (int lane = 0; lane < 4; lane++) begin
                    if (next_strb[lane])
                        regs[next_addr[3:2]][8*lane +: 8] <= next_data[8*lane +: 8];
                end
            end

            if (rvalid && rready) rvalid <= 0;
            if (arvalid && arready) begin
                rvalid <= 1;
                rresp  <= mapped(araddr) ? OKAY : SLVERR;
                // Nonblocking writes preserve old data for a same-edge read.
                rdata  <= mapped(araddr) ? regs[araddr[3:2]] : 32'b0;
            end
        end
    end
endmodule
