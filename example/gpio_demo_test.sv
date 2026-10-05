import uvm_pkg::*;
`include "uvm_macros.svh"
import gpio_pkg::*;

class gpio_demo_scoreboard extends uvm_component;

  `uvm_component_utils(gpio_demo_scoreboard)

  uvm_analysis_imp #(gpio_seq_item, gpio_demo_scoreboard) analysis_export;
  gpio_config cfg;

  int unsigned checks;
  int unsigned errors;

  function new(string name = "gpio_demo_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(gpio_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("GPIO_SB", "gpio_config was not provided to demo scoreboard")
  endfunction

  function void write(gpio_seq_item t);
    bit [31:0] m;

    if (t.during_reset)
      return;

    m = cfg.active_mask();
    checks++;

    if ((t.sample_out & m) !== (t.sample_in & m)) begin
      errors++;
      `uvm_error("GPIO_SB",
        $sformatf("Loopback mismatch: in=0x%08h out=0x%08h mask=0x%08h",
                  t.sample_in, t.sample_out, m))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    if (errors == 0)
      `uvm_info("GPIO_SB",
        $sformatf("PASS: %0d GPIO samples checked, 0 mismatches", checks),
        UVM_NONE)
    else
      `uvm_error("GPIO_SB",
        $sformatf("FAIL: %0d checks, %0d mismatches", checks, errors))
  endfunction

endclass


class gpio_demo_env extends uvm_env;

  `uvm_component_utils(gpio_demo_env)

  gpio_agent           agent;
  gpio_demo_scoreboard scoreboard;

  function new(string name = "gpio_demo_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = gpio_agent::type_id::create("agent", this);
    scoreboard = gpio_demo_scoreboard::type_id::create("scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.analysis_port.connect(scoreboard.analysis_export);
  endfunction

endclass


class gpio_demo_test extends uvm_test;

  `uvm_component_utils(gpio_demo_test)

  virtual gpio_if vif;
  gpio_config      cfg;
  gpio_demo_env    env;

  function new(string name = "gpio_demo_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual gpio_if)::get(this, "", "vif", vif))
      `uvm_fatal("GPIO_TEST", "virtual gpio_if was not provided")

    cfg = gpio_config::type_id::create("cfg");
    cfg.vif             = vif;
    cfg.is_active       = UVM_ACTIVE;
    cfg.num_pins        = 16;
    cfg.idle_value      = '0;
    cfg.enable_coverage = 1'b1;

    uvm_config_db#(gpio_config)::set(this, "env.agent",      "cfg", cfg);
    uvm_config_db#(gpio_config)::set(this, "env.scoreboard", "cfg", cfg);

    env = gpio_demo_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    gpio_smoke_seq  smoke;
    gpio_random_seq random_seq;

    phase.raise_objection(this);

    wait (vif.rst_n === 1'b1);
    repeat (2) @(posedge vif.clk);

    smoke = gpio_smoke_seq::type_id::create("smoke");
    smoke.num_pins = cfg.num_pins;
    smoke.start(env.agent.sequencer);

    random_seq = gpio_random_seq::type_id::create("random_seq");
    random_seq.num_pins  = cfg.num_pins;
    random_seq.num_items = 20;
    random_seq.start(env.agent.sequencer);

    repeat (2) @(posedge vif.clk);

    phase.drop_objection(this);
  endtask

endclass
