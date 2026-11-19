# Week 1 Simulation Evidence

| File | Evidence |
| --- | --- |
| [week1_icarus.log](week1_icarus.log) | Actual Icarus Verilog run with sampled bus values, directed checks, 100 completed writes in the 300-cycle window, and two cycles of write latency |
| [week1_baseline.vcd](week1_baseline.vcd) | Signal trace from the same run |
| [week1_write_readback.png](week1_write_readback.png) | Plot of the basic write/readback transaction extracted from that trace |

The write/readback waveform shows AW/W acceptance, the B handshake,
AR acceptance, and the R handshake with `0x12345678` read from `0x00`.
See [the run instructions](../README.md#reproduce-in-questa) for generating
your own Questa transcript and WLF. Keep the tool name with each result.

The Questa GUI script saves its own trace to `week1_questa_gui.log` after you run it.
