`timescale 1ns/1ps

module tb_smoke;
    localparam logic [1:0] OKAY = 2'b00, SLVERR = 2'b10;

    logic aclk = 0;
    logic aresetn = 0;
    logic [7:0] awaddr = 0, araddr = 0;
    logic [2:0] awprot = 0, arprot = 0;
    logic [31:0] wdata = 0, rdata;
    logic [3:0] wstrb = 0;
    logic awvalid = 0, wvalid = 0, arvalid = 0;
    logic awready, wready, arready;
    logic bvalid, rvalid, bready = 0, rready = 0;
    logic [1:0] bresp, rresp;

    axi_lite_baseline dut (.*);
    always #5 aclk = ~aclk;

    bit test_passed = 0;
    bit trace_basic = 0;
    bit trace_all = 0;
    int accepted_aw, accepted_w, completed_b, accepted_ar, completed_r;
    bit b_was_stalled, r_was_stalled;
    logic [1:0] previous_bresp, previous_rresp;
    logic [31:0] previous_rdata;

    initial begin
        trace_all = $test$plusargs("TRACE_ALL");
        if ($test$plusargs("VCD")) begin
            $dumpfile("Results/week1_baseline.vcd");
            $dumpvars(1, tb_smoke);
            $dumpvars(1, tb_smoke.dut);
        end
    end

    // Use the same rising-edge values the bus endpoints sample, before NBA updates.
    // The default trace shows just the first checked write/readback transaction.
    always @(posedge aclk) begin
        if (aresetn && (trace_basic || trace_all)) begin
            if (awvalid && awready)
                $display("[TRACE %0d ns] AW  AWVALID=%b AWREADY=%b AWADDR=0x%02h",
                         $time, awvalid, awready, awaddr);
            if (wvalid && wready)
                $display("[TRACE %0d ns] W   WVALID=%b WREADY=%b WDATA=0x%08h WSTRB=0b%04b",
                         $time, wvalid, wready, wdata, wstrb);
            if (dut.commit_write)
                $display("[TRACE %0d ns] COMMIT COMMIT_WRITE=%b AW_PENDING=%b W_PENDING=%b ADDR=0x%02h DATA=0x%08h STRB=0b%04b",
                         $time, dut.commit_write, dut.aw_pending, dut.w_pending,
                         dut.saved_addr, dut.saved_data, dut.saved_strb);
            if (bvalid && bready)
                $display("[TRACE %0d ns] B   BVALID=%b BREADY=%b BRESP=0b%02b",
                         $time, bvalid, bready, bresp);
            if (arvalid && arready)
                $display("[TRACE %0d ns] AR  ARVALID=%b ARREADY=%b ARADDR=0x%02h",
                         $time, arvalid, arready, araddr);
            if (rvalid && rready)
                $display("[TRACE %0d ns] R   RVALID=%b RREADY=%b RDATA=0x%08h RRESP=0b%02b",
                         $time, rvalid, rready, rdata, rresp);
        end
    end

    // Pin-level accounting. Check the baseline can hold at most one request
    // per channel, and that every visible response has a corresponding request.
    always @(posedge aclk) begin
        if (!aresetn) begin
            accepted_aw = 0; accepted_w = 0; completed_b = 0;
            accepted_ar = 0; completed_r = 0;
            b_was_stalled = 0; r_was_stalled = 0;
            previous_bresp = '0; previous_rresp = '0; previous_rdata = '0;
        end else begin
            if (b_was_stalled && (bvalid !== 1'b1 || bresp !== previous_bresp))
                $fatal(1, "B changed after a stalled edge");
            if (r_was_stalled && (rvalid !== 1'b1 || rresp !== previous_rresp ||
                                  rdata !== previous_rdata))
                $fatal(1, "R changed after a stalled edge");
            b_was_stalled = bvalid && !bready;
            r_was_stalled = rvalid && !rready;
            previous_bresp = bresp;
            previous_rresp = rresp;
            previous_rdata = rdata;
            if (bvalid && ((awvalid && awready) || (wvalid && wready)))
                $fatal(1, "Accepted a new write before previous B completed");
            if (rvalid && arvalid && arready)
                $fatal(1, "Accepted a new read before previous R completed");
            if (bvalid && (completed_b >= accepted_aw || completed_b >= accepted_w))
                $fatal(1, "B response has no accepted AW/W pair");
            if (rvalid && completed_r >= accepted_ar)
                $fatal(1, "R response has no accepted AR");
            if (awvalid && awready) accepted_aw++;
            if (wvalid && wready) accepted_w++;
            if (arvalid && arready) accepted_ar++;
            if (bvalid && bready) completed_b++;
            if (rvalid && rready) completed_r++;
            if (accepted_aw-completed_b > 1 || accepted_w-completed_b > 1 ||
                accepted_ar-completed_r > 1)
                $fatal(1, "More than one request outstanding in baseline");
        end
    end

    task automatic reset_bus;
        @(negedge aclk);
        aresetn = 0;
        awvalid = 0; wvalid = 0; arvalid = 0; bready = 0; rready = 0;
        repeat (3) @(posedge aclk);
        if (bvalid !== 1'b0 || rvalid !== 1'b0)
            $fatal(1, "Stale response at reset");
        // Release immediately after a rising edge, after the DUT samples reset.
        aresetn <= 1;
        @(negedge aclk);
    endtask

    // Drive on falling edges and sample transfers on rising edges.
    // This task returns on the falling edge after the later AW/W transfer.
    task automatic send_write(input logic [7:0] addr,
                              input logic [31:0] data,
                              input logic [3:0] mask,
                              input int aw_delay = 0,
                              input int w_delay = 0);
        bit aw_done, w_done;
        int elapsed;
        aw_done = 0; w_done = 0; elapsed = 0;
        @(negedge aclk);
        awaddr = addr; wdata = data; wstrb = mask;
        while (!aw_done || !w_done) begin
            awvalid = !aw_done && elapsed >= aw_delay;
            wvalid  = !w_done  && elapsed >= w_delay;
            @(posedge aclk);
            if (awvalid && awready) aw_done = 1;
            if (wvalid && wready) w_done = 1;
            @(negedge aclk);
            elapsed++;
        end
        awvalid = 0; wvalid = 0;
    endtask

    task automatic take_b(input logic [1:0] expected, input int stall_cycles = 0);
        // Start with BREADY low so a response remains visible until checked.
        while (bvalid !== 1'b1) @(negedge aclk);
        repeat (stall_cycles) begin
            @(posedge aclk);
            if (bvalid !== 1'b1 || bresp !== expected || awready !== 0 || wready !== 0)
                $fatal(1, "Incorrect response or premature readiness during B stall");
            @(negedge aclk);
        end
        bready = 1;
        @(posedge aclk);
        if (bvalid !== 1'b1 || bresp !== expected)
            $fatal(1, "BRESP expected %b, got %b", expected, bresp);
        @(negedge aclk);
        bready = 0;
    endtask

    task automatic send_read(input logic [7:0] addr);
        araddr = addr; arvalid = 1;
        do @(posedge aclk); while (arready !== 1'b1);
        @(negedge aclk);
        arvalid = 0;
    endtask

    task automatic take_r(input logic [31:0] expected_data,
                          input logic [1:0] expected_resp,
                          input int stall_cycles = 0);
        while (rvalid !== 1'b1) @(negedge aclk);
        repeat (stall_cycles) begin
            @(posedge aclk);
            if (rvalid !== 1'b1 || rdata !== expected_data ||
                rresp !== expected_resp || arready !== 0)
                $fatal(1, "Incorrect response or premature readiness during R stall");
            @(negedge aclk);
        end
        rready = 1;
        @(posedge aclk);
        if (rvalid !== 1'b1 || rdata !== expected_data || rresp !== expected_resp)
            $fatal(1, "Read expected %h/%b, got %h/%b",
                   expected_data, expected_resp, rdata, rresp);
        @(negedge aclk);
        rready = 0;
    endtask

    task automatic check_read(input logic [7:0] addr,
                              input logic [31:0] expected,
                              input logic [1:0] response = OKAY,
                              input int stall_cycles = 0);
        @(negedge aclk);
        send_read(addr);
        take_r(expected, response, stall_cycles);
    endtask

    task automatic check_all_strobes;
        localparam logic [31:0] INITIAL_DATA = 32'h1122_3344;
        localparam logic [31:0] NEXT_DATA = 32'heedd_ccbb;
        logic [3:0] mask;
        logic [31:0] bit_mask, expected;
        for (int i = 0; i < 16; i++) begin
            mask = i[3:0];
            bit_mask = {{8{mask[3]}}, {8{mask[2]}}, {8{mask[1]}}, {8{mask[0]}}};
            expected = (INITIAL_DATA & ~bit_mask) | (NEXT_DATA & bit_mask);
            send_write(8'h0c, INITIAL_DATA, 4'hf);
            take_b(OKAY);
            send_write(8'h0c, NEXT_DATA, mask);
            take_b(OKAY);
            check_read(8'h0c, expected);
        end
    endtask

    task automatic reset_during_partial_write(input bit address_only);
        @(negedge aclk);
        awaddr = 8'h08;
        wdata = 32'hdead_beef;
        wstrb = 4'hf;
        awvalid = address_only;
        wvalid = !address_only;
        @(posedge aclk);
        if ((address_only && awready !== 1'b1) ||
            (!address_only && wready !== 1'b1))
            $fatal(1, "Partial write was not accepted before reset");
        @(negedge aclk);
        awvalid = 0;
        wvalid = 0;
        reset_bus();
        @(posedge aclk);
        if (awready !== 1'b1 || wready !== 1'b1 || bvalid !== 1'b0)
            $fatal(1, "Incomplete write survived reset");
        send_write(8'h08, 32'h1122_aabb, 4'hf, address_only ? 2 : 0,
                                                 address_only ? 0 : 2);
        take_b(OKAY);
        check_read(8'h08, 32'h1122_aabb);
    endtask

    // Each lane advances after its own handshake. Neither waits for B.
    task automatic measure_continuous;
        localparam int TOTAL = 400, WARMUP = 20, WINDOW = 300;
        int aw_cycle [0:TOTAL-1];
        int w_cycle [0:TOTAL-1];
        int aw_sent, w_sent, b_seen, cycle, window_writes;
        int last_input_edge, latency, latency_min, latency_max, latency_sum;
        aw_sent = 0; w_sent = 0; b_seen = 0; cycle = 0; window_writes = 0;
        latency_min = 100000; latency_max = 0; latency_sum = 0;
        @(negedge aclk);
        bready = 1;
        wstrb = 4'hf;
        while (b_seen < TOTAL) begin
            awvalid = aw_sent < TOTAL;
            wvalid  = w_sent < TOTAL;
            awaddr  = {4'b0, aw_sent[1:0], 2'b00};
            wdata   = w_sent;
            @(posedge aclk);
            if (awvalid && awready) begin
                aw_cycle[aw_sent] = cycle;
                aw_sent++;
            end
            if (wvalid && wready) begin
                w_cycle[w_sent] = cycle;
                w_sent++;
            end
            if (bvalid && bready) begin
                if (bresp !== OKAY || b_seen >= aw_sent || b_seen >= w_sent)
                    $fatal(1, "Unexpected write response during benchmark");
                last_input_edge = aw_cycle[b_seen] > w_cycle[b_seen]
                                ? aw_cycle[b_seen] : w_cycle[b_seen];
                latency = cycle - last_input_edge;
                if (latency < latency_min) latency_min = latency;
                if (latency > latency_max) latency_max = latency;
                latency_sum += latency;
                b_seen++;
                if (cycle >= WARMUP && cycle < WARMUP + WINDOW)
                    window_writes++;
            end
            cycle++;
            @(negedge aclk);
        end
        awvalid = 0; wvalid = 0; bready = 0;
        if (aw_sent != TOTAL || w_sent != TOTAL || cycle < WARMUP+WINDOW ||
            window_writes == 0)
            $fatal(1, "Invalid throughput measurement");
        $display("BASELINE_METRIC writes=%0d cycles=%0d writes_per_cycle=%0.6f batch_cycles=%0d",
                 window_writes, WINDOW, real'(window_writes)/WINDOW, cycle);
        $display("BASELINE_LATENCY transactions=%0d min_cycles=%0d mean_cycles=%0.3f max_cycles=%0d",
                 b_seen, latency_min, real'(latency_sum)/b_seen, latency_max);
    endtask

    initial begin
        #100000;
        $fatal(1, "Simulation timeout");
    end

    initial begin
        reset_bus();
        check_read(8'h00, 0);
        check_read(8'h04, 0);
        check_read(8'h08, 0);
        check_read(8'h0c, 0);

        $display("PASS reset register readback at all four addresses");
        $display("TRACE basic write/readback begins at %0d ns", $time);
        trace_basic = 1;
        send_write(8'h00, 32'h1234_5678, 4'hf);
        take_b(OKAY);
        check_read(8'h00, 32'h1234_5678);
        trace_basic = 0;
        $display("PASS simultaneous AW/W write and readback at %0d ns", $time);

        send_write(8'h04, 32'h1122_3344, 4'hf, 0, 3);
        take_b(OKAY, 3);
        check_read(8'h04, 32'h1122_3344, OKAY, 3);
        send_write(8'h08, 32'h8765_4321, 4'hf, 3, 0);
        take_b(OKAY);
        check_read(8'h08, 32'h8765_4321);
        $display("PASS AW-first, W-first and B/R backpressure");

        send_write(8'h04, 32'haabb_ccdd, 4'b0101);
        take_b(OKAY);
        check_read(8'h04, 32'h11bb_33dd);
        send_write(8'h04, 32'hffff_ffff, 4'h0);
        take_b(OKAY);
        check_read(8'h04, 32'h11bb_33dd);
        send_write(8'h10, 32'hffff_ffff, 4'hf);
        take_b(SLVERR);
        send_write(8'h02, 32'hffff_ffff, 4'hf);
        take_b(SLVERR);
        check_read(8'h10, 0, SLVERR);
        check_read(8'h02, 0, SLVERR);
        check_read(8'h00, 32'h1234_5678);
        check_read(8'h04, 32'h11bb_33dd);
        check_read(8'h08, 32'h8765_4321);
        check_read(8'h0c, 0);
        $display("PASS partial and zero strobes, and invalid/misaligned accesses");

        check_all_strobes();
        $display("PASS all 16 byte-strobe masks");
        send_write(8'h00, 32'hcafe_f00d, 4'hf);
        // AR is accepted on the next rising edge, the write commit edge.
        send_read(8'h00);
        take_r(32'h1234_5678, OKAY);
        take_b(OKAY);
        check_read(8'h00, 32'hcafe_f00d);
        $display("PASS old value on same-edge read/write");

        send_write(8'h0c, 32'h0102_0304, 4'hf);
        send_read(8'h0c);
        if (bvalid !== 1 || rvalid !== 1)
            $fatal(1, "Reset test did not reach pending B and R");
        reset_bus();
        check_read(8'h0c, 0);
        check_read(8'h00, 0);
        send_write(8'h0c, 32'h0000_00a5, 4'hf);
        take_b(OKAY);
        check_read(8'h0c, 32'h0000_00a5);
        reset_during_partial_write(1);
        reset_during_partial_write(0);
        $display("PASS partial-write and pending-response reset recovery");

        reset_bus();
        measure_continuous();
        check_read(8'h00, 396);
        check_read(8'h04, 397);
        check_read(8'h08, 398);
        check_read(8'h0c, 399);
        repeat (3) @(negedge aclk);
        if (accepted_aw != completed_b || accepted_w != completed_b ||
            accepted_ar != completed_r || bvalid || rvalid)
            $fatal(1, "Undrained responses at end of test");
        $display("PASS final readback and response accounting after 400 writes");
        test_passed = 1;
        $display("WEEK1_PASS");
        $finish;
    end
endmodule
