# Find the Week 1 sources relative to the current directory or this script.
# Supported layouts: RTL/ and Testbench/ subfolders, or both files together.
set launch_dir [pwd]
set candidates [list $launch_dir [file join $launch_dir Week_1]]
if {[string equal -nocase [file tail $launch_dir] Scripts]} {
    lappend candidates [file dirname $launch_dir]
}
set macro_file [info script]
if {$macro_file ne ""} {
    set macro_dir [file dirname [file normalize $macro_file]]
    lappend candidates $macro_dir
    if {[string equal -nocase [file tail $macro_dir] Scripts]} {
        lappend candidates [file dirname $macro_dir]
    }
}

set week1_root ""
foreach folder $candidates {
    foreach layout {{RTL/axi_lite_baseline.sv Testbench/tb_smoke.sv}
                    {axi_lite_baseline.sv tb_smoke.sv}} {
        lassign $layout rtl_name tb_name
        set rtl_file [file join $folder $rtl_name]
        set tb_file [file join $folder $tb_name]
        if {[file isfile $rtl_file] && [file isfile $tb_file]} {
            set week1_root [file normalize $folder]
            set rtl_file [file normalize $rtl_file]
            set tb_file [file normalize $tb_file]
            break
        }
    }
    if {$week1_root ne ""} {break}
}

if {$week1_root eq ""} {
    error "Cannot find both AXI4-Lite source files. Questa is in $launch_dir. Change to the folder containing RTL/axi_lite_baseline.sv and Testbench/tb_smoke.sv, or the folder containing both .sv files."
}

cd $week1_root
catch {quit -sim}
file mkdir Results
set week1_transcript [file join $week1_root Results week1_questa_gui.log]
transcript file $week1_transcript
puts "Week 1 source folder: $week1_root"
puts "Week 1 transcript: $week1_transcript"

# Recreate the local compiled work library.
if {![file exists modelsim.ini]} {
    vmap -c
}
if {[file isdirectory work]} {
    vmap work work
    vdel -lib work -all
}
vlib work
vmap work work

# Compile the RTL and the directed testbench.
vlog -sv -work work $rtl_file
vlog -sv -work work $tb_file

# Load the testbench and keep the GUI open after $finish.
if {[info exists week1_trace_all] && $week1_trace_all} {
    vsim -voptargs=+acc work.tb_smoke +TRACE_ALL
} else {
    vsim -voptargs=+acc work.tb_smoke
}
onfinish stop

view wave

add wave -divider "CLOCK AND RESET"
add wave sim:/tb_smoke/aclk sim:/tb_smoke/aresetn

add wave -divider "AW - WRITE ADDRESS"
add wave -radix hexadecimal sim:/tb_smoke/awaddr
add wave sim:/tb_smoke/awvalid sim:/tb_smoke/awready

add wave -divider "W - WRITE DATA"
add wave -radix hexadecimal sim:/tb_smoke/wdata
add wave -radix binary sim:/tb_smoke/wstrb
add wave sim:/tb_smoke/wvalid sim:/tb_smoke/wready

add wave -divider "BASELINE WRITE STATE"
add wave sim:/tb_smoke/dut/aw_pending sim:/tb_smoke/dut/w_pending
add wave sim:/tb_smoke/dut/commit_write

add wave -divider "B - WRITE RESPONSE"
add wave -radix binary sim:/tb_smoke/bresp
add wave sim:/tb_smoke/bvalid sim:/tb_smoke/bready

add wave -divider "AR - READ ADDRESS"
add wave -radix hexadecimal sim:/tb_smoke/araddr
add wave sim:/tb_smoke/arvalid sim:/tb_smoke/arready

add wave -divider "R - READ RESPONSE"
add wave -radix hexadecimal sim:/tb_smoke/rdata
add wave -radix binary sim:/tb_smoke/rresp
add wave sim:/tb_smoke/rvalid sim:/tb_smoke/rready

add wave -divider "TEST STATUS"
add wave sim:/tb_smoke/test_passed

run -all
wave zoom full
