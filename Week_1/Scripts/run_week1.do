# Launch from Week_1. The transcript is selected on the vsim command line.
onerror {quit -f -code 1}
if {![file isdirectory Results]} {file mkdir Results}
if {![file isdirectory work]} {vlib work}
vlog -sv RTL/axi_lite_baseline.sv Testbench/tb_smoke.sv
vsim -voptargs=+acc work.tb_smoke
onfinish stop
log -r /tb_smoke/*
run -all
if {[examine -radix unsigned /tb_smoke/test_passed] ne "1"} {
    puts "ERROR: Test ended without WEEK1_PASS"
    quit -f -code 1
}
quit -f -code 0
