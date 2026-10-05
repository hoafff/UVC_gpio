class gpio_driver extends uvm_driver #(gpio_seq_item);

  `uvm_component_utils(gpio_driver)

  gpio_config cfg;

  function new(string name = "gpio_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(gpio_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("GPIO_DRV", "gpio_config was not provided to gpio_driver")

    cfg.validate();
  endfunction

  task run_phase(uvm_phase phase);
    gpio_seq_item req;

    // Deterministic initial value before the first sequence item arrives.
    cfg.vif.gpio_in = cfg.idle_value;

    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  protected task drive_item(gpio_seq_item tr);
    bit [31:0] active_mask;
    bit [31:0] effective_mask;
    bit [31:0] next_value;

    active_mask = cfg.active_mask();

    // While reset is asserted, keep external GPIO stimulus at idle.
    while (cfg.vif.rst_n !== 1'b1) begin
      @(cfg.vif.drv_cb);
      cfg.vif.drv_cb.gpio_in <= cfg.idle_value;
    end

    effective_mask = tr.mask & active_mask;

    @(cfg.vif.drv_cb);

    next_value = cfg.vif.gpio_in;
    next_value = (next_value & ~effective_mask) |
                 (tr.data   &  effective_mask);

    // Pins outside cfg.num_pins are always held at the configured idle value.
    next_value = (next_value    &  active_mask) |
                 (cfg.idle_value & ~active_mask);

    cfg.vif.drv_cb.gpio_in <= next_value;

    repeat (tr.hold_cycles)
      @(cfg.vif.drv_cb);

    `uvm_info("GPIO_DRV",
      $sformatf("Drove GPIO: data=0x%08h mask=0x%08h hold=%0d",
                tr.data, effective_mask, tr.hold_cycles),
      UVM_HIGH)
  endtask

endclass
