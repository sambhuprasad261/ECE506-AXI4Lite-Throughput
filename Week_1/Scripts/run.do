# Run from the active Week_1 directory.
if {![file isfile RTL/axi_lite_baseline.sv] ||
    ![file isfile Testbench/tb_smoke.sv]} {
    error "Run from Week_1. Current directory: [pwd]"
}

catch {quit -sim}
file mkdir Results

if {[file isdirectory work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vlog -sv RTL/axi_lite_baseline.sv
vlog -sv Testbench/tb_smoke.sv

vsim -voptargs=+acc -wlf Results/week1_questa.wlf work.tb_smoke +TRACE_ALL

transcript file [file normalize Results/week1_questa.log]
transcript on

add wave -r sim:/tb_smoke/*

vcd file Results/week1_questa.vcd
vcd add -r sim:/tb_smoke/*
vcd on

onfinish stop
onbreak {resume}
run -all

transcript off
transcript file ""
wave zoom full




