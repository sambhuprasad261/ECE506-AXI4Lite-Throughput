# Run from Week_2 in the Questa GUI Transcript.
# Set use_buffered to 0 before running this script to select the baseline.
if {![file isfile RTL/axi_lite_buffered.sv] ||
    ![file isfile Testbench/tb_week2.sv]} {
    error "Run from Week_2. Current directory: [pwd]"
}

if {![info exists use_buffered]} {set use_buffered 1}
if {$use_buffered ni {0 1}} {error "Set use_buffered to 0 or 1"}
set variant [expr {$use_buffered ? "buffered" : "baseline"}]
set results_dir [file normalize Results]
file mkdir $results_dir

catch {quit -sim}
if {![file exists modelsim.ini]} {vmap -c}
if {![file isdirectory work]} {vlib work}
vmap work [file normalize work]

vlog -sv RTL/fifo2.sv RTL/axi_lite_baseline.sv RTL/axi_lite_buffered.sv
vlog -sv Testbench/tb_week2.sv

vsim -voptargs=+acc -gUSE_BUFFERED=$use_buffered \
    -wlf [file join $results_dir questa_${variant}.wlf] work.tb_week2 +TRACE_ALL

transcript file [file join $results_dir questa_${variant}.log]
transcript on

add wave -r sim:/tb_week2/*
vcd file [file join $results_dir questa_${variant}.vcd]
vcd add -r sim:/tb_week2/*
vcd on

onfinish stop
onbreak {resume}
run -all

vcd flush
transcript off
transcript file ""
wave zoom full
