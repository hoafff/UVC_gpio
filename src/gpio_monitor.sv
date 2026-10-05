class gpio_monitor extends uvm_monitor;

  `uvm_component_utils(gpio_monitor)

  gpio_config cfg;
  uvm_analysis_port #(gpio_seq_item) ap;

  function new(string name = "gpio_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(gpio_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("GPIO_MON", "gpio_config was not provided to gpio_monitor")

    cfg.validate();
  endfunction

  task run_phase(uvm_phase phase);
    gpio_seq_item tr;

    forever begin
      @(cfg.vif.mon_cb);

      if ((cfg.vif.mon_cb.rst_n === 1'b1) || cfg.monitor_during_reset) begin
        tr = gpio_seq_item::type_id::create("tr", this);

        tr.sample_in    = cfg.vif.mon_cb.gpio_in;
        tr.sample_out   = cfg.vif.mon_cb.gpio_out;
        tr.sample_oe    = cfg.vif.mon_cb.gpio_oe;
        tr.during_reset = (cfg.vif.mon_cb.rst_n !== 1'b1);
        tr.sample_time  = $time;

        ap.write(tr);

        `uvm_info("GPIO_MON", tr.convert2string(), UVM_HIGH)
      end
    end
  endtask

endclass
