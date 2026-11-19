# Formal verification plan

Status: planned for a later milestone. The Week 1 testbench uses simulation
checks and produces no formal proof results.

| Planned property | Expected behavior |
| --- | --- |
| B stability | If BVALID is high and BREADY is low, retain BVALID and BRESP through the next sampled edge, unless reset intervenes. |
| R stability | If RVALID is high and RREADY is low, retain RVALID, RDATA and RRESP through the next sampled edge, unless reset intervenes. |
| Response accounting | A B response has a previously accepted AW/W pair, and an R response has a previously accepted AR. |
| Write acceptance limit | The baseline does not take another request of either write channel while the current response is pending. |
| Register effects | Check byte enables, invalid access behavior, and the old value on a same-edge read/write. |
| Reset | Clear pending work and register contents. |

For VC Formal, assume that the manager holds AW, W and AR payloads stable
while stalled. Cover split arrivals, backpressure and reset with pending
traffic. Record assertion status, cover reachability, COI and proof core
once actual runs are available.
