# Week 1 Verification Checklist

The table records directed simulation of the baseline in Icarus Verilog.
The primary evidence is [week1_icarus.log](../Results/week1_icarus.log).
Questa, UVM coverage and formal proof are separate results.

| Proposal behavior | Week 1 check | Directed simulation |
| --- | --- | --- |
| AW first, W first, or simultaneous | Three directed write/readback cases | Pass |
| No B response before the corresponding AW and W | Pin-level response accounting and split-arrival tests | Pass |
| Baseline holds at most one write outstanding | Pin-level monitor and 400-write continuous benchmark | Pass |
| Exactly one B response per completed write | Outstanding counts, response checks and end-of-test drain check | Pass |
| Byte lanes are updated by WSTRB | Compare readback for every mask from 0 to 15 using distinct byte values | Pass |
| Invalid or misaligned write changes no register | Check SLVERR and read all four registers afterward | Pass |
| Valid and invalid reads | Check all four mapped words, aligned-unmapped and misaligned addresses | Pass |
| Read is sampled on the AR handshake | Check same-edge capture and hold response under backpressure | Pass |
| Only one read outstanding | Pin-level accounting and a stalled R response | Pass |
| Same-edge AR handshake and write commit return old data | Check old data in the collision and new data on the next read | Pass |
| B and R valid/payload stability during stalls | Edge-to-edge checks and directed B/R stall cases | Pass |
| Reset clears registers and pending transactions | Reset after AW alone, W alone, and pending B/R; verify fresh traffic | Pass |
| Buffered order and two-entry queue boundaries | Exercise once buffered RTL is implemented | Later milestone |

Every status above refers to the directed cases run. Functional coverage
percentages, formal property outcomes, and synthesis results are not measured
by this testbench.
