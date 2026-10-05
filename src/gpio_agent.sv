class gpio_agent extends uvm_agent;

  `uvm_component_utils(gpio_agent)

  gpio_config    cfg;
  gpio_sequencer sequencer;
  gpio_driver    driver;
  gpio_monitor   monitor;
  gpio_coverage  coverage;

  uvm_analysis_port #(gpio_seq_item) analysis_port;

  function new(string name = "gpio_agent", uvm_component parent = null);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(gpio_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("GPIO_AGENT", "gpio_config was not provided to gpio_agent")

    cfg.validate();

    uvm_config_db#(gpio_config)::set(this, "monitor", "cfg", cfg);
    monitor = gpio_monitor::type_id::create("monitor", this);

    if (cfg.enable_coverage) begin
      uvm_config_db#(gpio_config)::set(this, "coverage", "cfg", cfg);
      coverage = gpio_coverage::type_id::create("coverage", this);
    end

    if (cfg.is_active == UVM_ACTIVE) begin
      uvm_config_db#(gpio_config)::set(this, "driver", "cfg", cfg);
      sequencer = gpio_sequencer::type_id::create("sequencer", this);
      driver    = gpio_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    monitor.ap.connect(analysis_port);

    if (coverage != null)
      monitor.ap.connect(coverage.analysis_export);

    if (cfg.is_active == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction

endclass
