# Week 2 Buffered AXI4-Lite Write Path

The buffered peripheral has the same ports and register behavior as the
Week 1 baseline. It adds two registered entries each for AW, W, and B.
A write commits when the oldest AW and W entries are available and the
B FIFO has space. AW and W are removed together at commit. The response
is enqueued at the same edge and completed on a rising edge with both
BVALID and BREADY high.

| Queue | Entry | Push | Pop |
| --- | --- | --- | --- |
| AW | 8-bit byte address | AW handshake | Write commit |
| W | 32-bit data and four byte enables | W handshake | Write commit |
| B | 2-bit response | Write commit | B handshake |

AWREADY and WREADY depend on registered FIFO occupancy and reset.
A FIFO that begins an edge full must pop before accepting a new push.
When a FIFO holds one entry, a push and pop can happen on the same edge
without changing occupancy. After the pipeline fills with BREADY high,
acceptance, commit, and completion can overlap for different writes.

The register map is 0x00, 0x04, 0x08, and 0x0C. Invalid or misaligned
addresses return SLVERR. Writes to those addresses leave the registers
intact. Reads sample the addressed register at the AR handshake and
return its pre-update value if a write commits on that same edge.
Reset clears the registers and pending transactions.

## Files and checks

- **RTL/fifo2.sv** implements the two-entry queues.
- **RTL/axi_lite_buffered.sv** implements the buffered peripheral.
- **RTL/axi_lite_baseline.sv** is the unchanged Week 1 baseline, included
  so both designs can be tested from this folder.
- **Testbench/tb_week2.sv** is the shared self-checking testbench. It checks
  simultaneous and split AW/W arrivals, all 16 byte masks, error responses,
  stalled responses, old-value read/write collision, reset, and final
  register values. Buffered-only cases check oldest-to-oldest pairing
  with two addresses or two data words accepted first, queue saturation,
  fifth-request backpressure, ordered response drain, and reset with
  all three write queues full.
- **Scripts/run.do** compiles, runs, and records the selected DUT in Questa.
- **Results/** contains the local Icarus Verilog logs and VCDs.

For the saturation waveform, search for **PASS fifth write stalled** in
the transcript. In the preceding stall interval BREADY, AWREADY, and
WREADY are low while BVALID, AWVALID, and WVALID are high. After release,
the response sequence for the five requests is OKAY, SLVERR, OKAY,
SLVERR, OKAY. The last three valid writes to 0x00, 0x04, and 0x08
are checked by readback.

## Run in Questa

Open Questa from the **Week_2** directory. In its Transcript, run:

```tcl
set use_buffered 1
do Scripts/run.do
```

Then run the baseline with the same testbench:

```tcl
set use_buffered 0
do Scripts/run.do
```

Under Results, each run writes its own **questa_buffered** or
**questa_baseline** log, WLF, and VCD. Full transaction tracing is enabled
for Questa. Check both logs for **WEEK2_PASS**, **METRIC**, and **LATENCY**.
The Icarus results below came from local runs. Record your Questa numbers
from your own logs after running the script.

## Measured comparison

Both local runs used the same 10 ns simulated clock, 400 offered writes,
BREADY held high, a 20-cycle warm-up, and a 300-cycle measurement window.
Each completed write was counted at its B handshake.

| Metric | Baseline | Buffered |
| --- | ---: | ---: |
| B handshakes in the 300-cycle window | 100 | 300 |
| Sustained writes per cycle | 0.333333 | 1.000000 |
| Cycles for the complete 400-write batch | 1200 | 402 |
| Write latency in cycles, min / mean / max | 2 / 2.000 / 2 | 2 / 2.000 / 2 |

The measured steady-state throughput ratio was **3.0×**. Write latency
is the edge of the B handshake minus the later edge of the AW or W
handshake. The reported latency is for the continuous benchmark with
BREADY high. The batch result includes fill and drain. This comparison
measures simulated cycles. Synthesis area and timing remain separate
project results.

Commit the Week_2 source tree and selected evidence from your run.
Keep simulator build files and large WLF databases local.
