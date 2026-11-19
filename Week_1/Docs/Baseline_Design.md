# Week 1 Baseline AXI4-Lite Design

The baseline is a single-outstanding AXI4-Lite register peripheral. It
uses a 32-bit data bus, an 8-bit byte address and one clock. The mapped
words are 0x00, 0x04, 0x08 and 0x0C. Mapped accesses return OKAY.
Unmapped or misaligned accesses return SLVERR. Invalid reads return zero,
and invalid writes leave the registers untouched. AWPROT and ARPROT are
present at the interface and do not affect this peripheral's behavior.

## Write and read timing

The RTL samples AW and W independently on rising-edge handshakes. The
address and the data with its byte strobes go into separate holding
registers. A write commits on the rising edge after both holding registers
are full. The response becomes valid after commit and stays valid until
accepted. The baseline can accept the next write on the rising edge after
the prior B handshake. A zero WSTRB is a successful no-op for mapped
addresses.

For a simultaneous AW/W transfer with no response stall:

| Rising edge | Event sampled at the edge |
| --- | --- |
| 1 | Accept address and data. |
| 2 | Commit the write and register the response. |
| 3 | Accept the B response when BREADY is high. |
| 4 | Accept the following address and data if the manager is offering them. |

The read path samples the register on the AR handshake and retains the
response through any R stall. If AR and a write commit target the same word
on the same edge, the read returns the old value. Active-low reset clears
the registers, holding state and response valid bits.

## Baseline measurement

The benchmark offers 400 valid writes with AW and W driven independently.
It holds BREADY high, skips 20 cycles, and counts B handshakes through
the next 300 cycles. It also reports whole-batch cycles, including the
first offer and last completion edges. The cycle table predicts one
completed write per three cycles under this workload. Use the value printed
by the actual simulator for your report.

The measured baseline was 100 responses in 300 cycles, or 0.333333 writes
per cycle. The 400-write batch took 1,200 cycles. Latency was 2 cycles
for every measured write, calculated as the B handshake cycle minus the
later of the AW and W handshake cycles. With the 10 ns simulated clock,
two cycles correspond to 20 ns of protocol latency. This clock is a test
setting. The synthesis timing comparison is a separate measurement.

Reference: Arm AMBA AXI and ACE Protocol Specification, IHI 0022H,
sections A3 and B1.
