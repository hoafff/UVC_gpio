class gpio_config extends uvm_object;

  `uvm_object_utils_begin(gpio_config)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
    `uvm_field_int(num_pins,             UVM_DEFAULT)
    `uvm_field_int(idle_value,           UVM_DEFAULT)
    `uvm_field_int(monitor_during_reset, UVM_DEFAULT)
    `uvm_field_int(enable_coverage,      UVM_DEFAULT)
  `uvm_object_utils_end

  virtual gpio_if vif;

  uvm_active_passive_enum is_active = UVM_ACTIVE;
  int unsigned            num_pins = 16;
  bit [31:0]              idle_value = '0;
  bit                     monitor_during_reset = 1'b0;
  bit                     enable_coverage = 1'b1;

  function new(string name = "gpio_config");
    super.new(name);
  endfunction

  function bit [31:0] active_mask();
    if (num_pins >= GPIO_UVC_MAX_WIDTH)
      return 32'hFFFF_FFFF;
    if (num_pins == 0)
      return 32'h0000_0000;
    return (32'h0000_0001 << num_pins) - 1'b1;
  endfunction

  function void validate();
    if (vif == null)
      `uvm_fatal("GPIO_CFG", "gpio_config.vif is null")
    if ((num_pins == 0) || (num_pins > GPIO_UVC_MAX_WIDTH))
      `uvm_fatal("GPIO_CFG",
        $sformatf("num_pins must be in range 1..%0d, got %0d",
                  GPIO_UVC_MAX_WIDTH, num_pins))
  endfunction

endclass
