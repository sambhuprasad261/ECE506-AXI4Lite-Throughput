# Week 1 Baseline AXI4-Lite Peripheral

This milestone implements and tests the single-outstanding baseline for
**Improving AXI4-Lite Write Throughput**. The revised ECE 506 proposal is in
[Docs](Docs/). The baseline accepts AW and W independently, commits the write
after both are captured, and waits for the B handshake before accepting
another write.

## Week 1 results

The RTL and testbench compiled and ran in Icarus Verilog WebAssembly
(`@veriflow/iverilog-wasm` 0.1.4, SystemVerilog 2012 mode). The testbench
printed `WEEK1_PASS`. The separate Questa run is pending.

| Metric | Measured result |
| --- | --- |
| Clock period | 10 ns |
| Warm-up | 20 cycles |
| Completed B handshakes in 300 measured cycles | 100 |
| Sustained throughput | 0.333333 writes per cycle |
| Batch of 400 completed writes | 1,200 cycles |
| Write latency, min / mean / max for all 400 writes | 2 / 2.000 / 2 cycles |

The benchmark holds BREADY high and continuously offers writes. Latency is
counted from the later of the AW and W handshakes to the B handshake.
See the [run log](Results/week1_icarus.log),
[write/readback waveform](Results/week1_write_readback.png), and
[verification checklist](Docs/Verification_Checklist.md).

## Files

| Location | Purpose |
| --- | --- |
| [RTL/axi_lite_baseline.sv](RTL/axi_lite_baseline.sv) | Synthesizable baseline peripheral |
| [Testbench/tb_smoke.sv](Testbench/tb_smoke.sv) | Directed tests, protocol checks, and continuous-write benchmark |
| [Scripts/run_week1.do](Scripts/run_week1.do) | Batch run for Questa |
| [Scripts/run_week1_gui.do](Scripts/run_week1_gui.do) | GUI waveform and Transcript run for Questa |
| [Docs/Baseline_Design.md](Docs/Baseline_Design.md) | Register map, timing, and measurement method |
| [Formal/README.md](Formal/README.md) | Planned formal checks |
| [Results](Results/) | Actual Icarus simulation evidence |

## Reproduce in Questa

From the **Week_1** directory, on a machine with Questa on PATH, run:

```text
vsim -c -l Results/week1_questa.log -wlf Results/week1_questa.wlf -do Scripts/run_week1.do
```

Check the transcript for `WEEK1_PASS`, `BASELINE_METRIC`, and
`BASELINE_LATENCY`. Record the Questa version and outcome here after running
it. The WLF is kept locally by default. You can upload a screenshot or
a VCD as the waveform evidence.

For the waveform window and a simultaneously saved Transcript, run this
from Week_1 on a machine with Questa GUI access:

```text
vsim -gui -do Scripts/run_week1_gui.do
```

The GUI script saves `Results/week1_questa_gui.log`. By default, the
testbench prints AW, W, write commit, B, AR, and R for the first checked
write/readback in both batch and GUI runs. Each line samples the actual
signals on the transfer or commit edge. To print every transaction in a
GUI run, enter these commands in the Transcript while in Week_1:

```tcl
set week1_trace_all 1
do Scripts/run_week1_gui.do
```

Use `set week1_trace_all 0` for a short trace again. The full trace
includes the 400-write benchmark, so the log will be much longer.

To reproduce using a native Icarus Verilog installation with SystemVerilog
support, run these commands from the same Week_1 directory:

```text
iverilog -g2012 -s tb_smoke -o week1.vvp RTL/axi_lite_baseline.sv Testbench/tb_smoke.sv
vvp week1.vvp +VCD
```

The optional `+VCD` creates or replaces `Results/week1_baseline.vcd`.

## Submit and continue

Keep the revised proposal files in Docs. Merge this Week_1 directory into
your clone, review the staged files, and commit from the repository root:

```powershell
git add -- Week_1/
git diff --cached --name-status
git commit -m "Week 1: Add AXI4-Lite baseline and directed verification"
git push origin main
```

After the Week 1 simulation is reproduced and the evidence is committed,
tag the baseline before starting the buffered write path:

```powershell
git tag -a week1-baseline -m "Verified Week 1 AXI4-Lite baseline"
git push origin week1-baseline
```

The buffered design, shared UVM regression and functional coverage, VC Formal
runs, and synthesis comparison are later milestones. The 2× throughput goal
requires an actual measurement of the buffered design using the same workload
and measurement rules.
