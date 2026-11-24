`timescale 1ns/1ps

module axi_lite_baseline (
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
    logic        aw_pending, w_pending;
    logic [7:0]  saved_addr;
    logic [31:0] saved_data;
    logic [3:0]  saved_strb;
    logic        commit_write;

    // This peripheral does not distinguish access protection attributes.
    function automatic logic mapped(input logic [7:0] addr);
        return (addr[7:4] == 4'h0) && (addr[1:0] == 2'b00);
    endfunction

    assign awready = aresetn && !aw_pending && !bvalid;
    assign wready  = aresetn && !w_pending  && !bvalid;
    assign arready = aresetn && !rvalid;
    assign commit_write = aw_pending && w_pending && !bvalid;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (int i = 0; i < 4; i++) regs[i] <= '0;
            aw_pending <= 0;
            w_pending  <= 0;
            saved_addr <= '0;
            saved_data <= '0;
            saved_strb <= '0;
            bvalid <= 0;
            bresp  <= OKAY;
            rvalid <= 0;
            rresp  <= OKAY;
            rdata  <= '0;
        end else begin
            if (awvalid && awready) begin
                saved_addr <= awaddr;
                aw_pending <= 1;
            end
            if (wvalid && wready) begin
                saved_data <= wdata;
                saved_strb <= wstrb;
                w_pending  <= 1;
            end
            if (bvalid && bready) bvalid <= 0;
            if (commit_write) begin
                aw_pending <= 0;
                w_pending  <= 0;
                bvalid <= 1;
                bresp  <= mapped(saved_addr) ? OKAY : SLVERR;
                if (mapped(saved_addr)) begin
                    for (int lane = 0; lane < 4; lane++) begin
                        if (saved_strb[lane])
                            regs[saved_addr[3:2]][8*lane +: 8] <= saved_data[8*lane +: 8];
                    end
                end
            end

            if (rvalid && rready) rvalid <= 0;
            if (arvalid && arready) begin
                rvalid <= 1;
                rresp  <= mapped(araddr) ? OKAY : SLVERR;
                // Nonblocking updates give the old value on a same-edge write.
                rdata  <= mapped(araddr) ? regs[araddr[3:2]] : 32'b0;
            end
        end
    end
endmodule
