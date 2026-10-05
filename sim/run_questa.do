transcript on

if {[file exists work]} {
  vdel -lib work -all
}
vlib work

# Locate uvm_macros.svh without hard-coding one PC installation path.
set uvm_src ""

if {[info exists ::env(UVM_HOME)]} {
  set candidate [file normalize [file join $::env(UVM_HOME) src]]
  if {[file exists [file join $candidate uvm_macros.svh]]} {
    set uvm_src $candidate
  }

  if {$uvm_src eq ""} {
    set candidate [file normalize $::env(UVM_HOME)]
    if {[file exists [file join $candidate uvm_macros.svh]]} {
      set uvm_src $candidate
    }
  }
}

if {$uvm_src eq ""} {
  set exe_dir [file dirname [info nameofexecutable]]
  set questa_root [file dirname $exe_dir]

  foreach uvm_ver {uvm-1.1d uvm-1.2} {
    set candidate [file normalize [file join $questa_root verilog_src $uvm_ver src]]
    if {[file exists [file join $candidate uvm_macros.svh]]} {
      set uvm_src $candidate
      break
    }
  }
}

if {$uvm_src eq ""} {
  puts "ERROR: Could not locate uvm_macros.svh."
  puts "Set UVM_HOME to your UVM installation before running this script."
  quit -code 2 -f
}

puts "Using UVM include directory: $uvm_src"

vlog -sv -L mtiUvm "+incdir+$uvm_src" -f sim/filelist.f

vsim -L mtiUvm work.tb_top +UVM_TESTNAME=gpio_demo_test

run -all
quit -f
