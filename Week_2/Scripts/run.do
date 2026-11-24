# Set use_buffered to 0 before running this script to select the baseline.
set week2_dir [file join $env(HOME) Documents ECE506-AXI4Lite-Throughput Week_2]
set rtl_dir [file join $week2_dir RTL]
set rtl_files [list [file join $rtl_dir fifo2.sv] \
                    [file join $rtl_dir axi_lite_baseline.sv] \
                    [file join $rtl_dir axi_lite_buffered.sv]]
set tb_file [file join $week2_dir Testbench tb_week2.sv]

foreach source_file [concat $rtl_files [list $tb_file]] {
    if {![file isfile $source_file]} {
        error "Missing Week 2 source file: $source_file"
    }
}

if {![info exists use_buffered]} {set use_buffered 1}
if {$use_buffered ni {0 1}} {error "Set use_buffered to 0 or 1"}
set variant [expr {$use_buffered ? "buffered" : "baseline"}]

catch {quit -sim}
cd $week2_dir
set results_dir [file join $week2_dir Results]
file mkdir $results_dir

if {![file exists modelsim.ini]} {vmap -c}
if {![file isdirectory work]} {vlib work}
vmap work [file normalize work]

vlog -sv {*}$rtl_files
vlog -sv $tb_file

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
