# Reusable GPIO UVC

A reusable **UVM Verification Component (UVC)** for generic GPIO interfaces.

The UVC is intentionally **DUT-independent**: it does not know about Counter16, a CPU, MCU, FPGA, or SoC. It only knows the generic GPIO signals exposed through `gpio_if`. A DUT-specific wrapper/adapter can map those generic signals to each project's real ports.

## Architecture

```text
Sequence
   |
   v
Sequencer -> Driver -> gpio_if -> DUT / DUT adapter
                         |
                         v
                      Monitor -> analysis_port -> scoreboard / coverage
```

`gpio_agent` supports both:

- **UVM_ACTIVE**: sequencer + driver + monitor
- **UVM_PASSIVE**: monitor only

## Generic GPIO model

The reusable interface exposes up to 32 pins:

- `gpio_in[31:0]`: value driven by the UVC toward DUT inputs
- `gpio_out[31:0]`: value driven by the DUT toward the UVC
- `gpio_oe[31:0]`: DUT output-enable/direction observation
- `clk`, `rst_n`: sampling clock and reset

`gpio_config.num_pins` selects how many low-order pins are active, so the same UVC source can be reused for 1..32 GPIO pins without editing the UVC.

## Repository layout

```text
src/
  gpio_if.sv
  gpio_pkg.sv
  gpio_types.sv
  gpio_config.sv
  gpio_seq_item.sv
  gpio_sequencer.sv
  gpio_driver.sv
  gpio_monitor.sv
  gpio_agent.sv
  gpio_coverage.sv
  gpio_sequences.sv

example/
  gpio_demo_dut.sv
  gpio_demo_test.sv
  tb_top.sv

sim/
  filelist.f
  run_questa.do
```

## Reuse model

Keep the UVC unchanged:

```text
Reusable GPIO UVC
        |
        v
     gpio_if
        |
        v
DUT-specific wrapper/adapter
        |
        v
       DUT
```

For example, a Counter16 adapter could map one GPIO input bit to `enable`, another to reset control, and map `count[15:0]` to GPIO outputs. That mapping belongs in the adapter, **not inside the UVC**.

## QuestaSim example

From the repository root:

```tcl
vsim -c -do sim/run_questa.do
```

The demo test runs zero/one, toggle, walking-one, and random GPIO sequences against a small registered loopback DUT.

## Design goals

- reusable across DUTs
- no DUT-specific signal names in UVC classes
- configurable active/passive agent
- configurable number of pins (1..32)
- masked GPIO stimulus
- monitor analysis port for external scoreboard/reference model
- optional functional coverage subscriber
- example testbench showing integration
