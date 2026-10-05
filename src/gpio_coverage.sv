class gpio_coverage extends uvm_subscriber #(gpio_seq_item);

  `uvm_component_utils(gpio_coverage)

  gpio_config cfg;

  bit in_nonzero;
  bit out_nonzero;
  bit oe_nonzero;
  bit out_lsb;

  covergroup gpio_cg;
    option.per_instance = 1;

    cp_in_nonzero  : coverpoint in_nonzero;
    cp_out_nonzero : coverpoint out_nonzero;
    cp_oe_nonzero  : coverpoint oe_nonzero;
    cp_out_lsb     : coverpoint out_lsb;

    cp_oe_vs_out : cross cp_oe_nonzero, cp_out_nonzero;
  endgroup

  function new(string name = "gpio_coverage", uvm_component parent = null);
    super.new(name, parent);
    gpio_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(gpio_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("GPIO_COV", "gpio_config was not provided to gpio_coverage")
  endfunction

  function void write(gpio_seq_item t);
    bit [31:0] m;

    if (!cfg.enable_coverage || t.during_reset)
      return;

    m = cfg.active_mask();

    in_nonzero  = |(t.sample_in  & m);
    out_nonzero = |(t.sample_out & m);
    oe_nonzero  = |(t.sample_oe  & m);
    out_lsb     = t.sample_out[0];

    gpio_cg.sample();
  endfunction

endclass
