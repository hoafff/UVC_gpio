class gpio_seq_item extends uvm_sequence_item;

  // Stimulus fields consumed by gpio_driver.
  rand bit [31:0] data;
  rand bit [31:0] mask;
  rand int unsigned hold_cycles;

  // Observation fields produced by gpio_monitor.
  logic [31:0] sample_in;
  logic [31:0] sample_out;
  logic [31:0] sample_oe;
  bit          during_reset;
  time         sample_time;

  constraint c_hold_cycles {
    hold_cycles inside {[1:1024]};
  }

  `uvm_object_utils_begin(gpio_seq_item)
    `uvm_field_int(data,         UVM_DEFAULT)
    `uvm_field_int(mask,         UVM_DEFAULT)
    `uvm_field_int(hold_cycles,  UVM_DEFAULT)
    `uvm_field_int(sample_in,    UVM_DEFAULT)
    `uvm_field_int(sample_out,   UVM_DEFAULT)
    `uvm_field_int(sample_oe,    UVM_DEFAULT)
    `uvm_field_int(during_reset, UVM_DEFAULT)
    `uvm_field_int(sample_time,  UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "gpio_seq_item");
    super.new(name);
    mask = 32'hFFFF_FFFF;
    hold_cycles = 1;
  endfunction

  function string convert2string();
    return $sformatf(
      "data=0x%08h mask=0x%08h hold=%0d | in=0x%08h out=0x%08h oe=0x%08h reset=%0b time=%0t",
      data, mask, hold_cycles,
      sample_in, sample_out, sample_oe, during_reset, sample_time
    );
  endfunction

endclass
