class gpio_base_seq extends uvm_sequence #(gpio_seq_item);

  `uvm_object_utils(gpio_base_seq)

  int unsigned num_pins = 16;

  function new(string name = "gpio_base_seq");
    super.new(name);
  endfunction

  function bit [31:0] seq_active_mask();
    if (num_pins >= GPIO_UVC_MAX_WIDTH)
      return 32'hFFFF_FFFF;
    if (num_pins == 0)
      return 32'h0000_0000;
    return (32'h0000_0001 << num_pins) - 1'b1;
  endfunction

  task send_value(bit [31:0] value,
                  bit [31:0] item_mask,
                  int unsigned cycles = 1);
    gpio_seq_item req;

    req = gpio_seq_item::type_id::create("req");
    start_item(req);

    req.data        = value;
    req.mask        = item_mask;
    req.hold_cycles = cycles;

    finish_item(req);
  endtask

endclass


class gpio_smoke_seq extends gpio_base_seq;

  `uvm_object_utils(gpio_smoke_seq)

  function new(string name = "gpio_smoke_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] m;

    if ((num_pins == 0) || (num_pins > GPIO_UVC_MAX_WIDTH))
      `uvm_fatal("GPIO_SEQ",
        $sformatf("gpio_smoke_seq num_pins must be 1..%0d, got %0d",
                  GPIO_UVC_MAX_WIDTH, num_pins))

    m = seq_active_mask();

    // Basic deterministic patterns.
    send_value(32'h0000_0000, m);
    send_value(m,             m);
    send_value(32'hAAAA_AAAA, m);
    send_value(32'h5555_5555, m);

    // Walking-one pattern.
    for (int unsigned i = 0; i < num_pins; i++)
      send_value(32'h0000_0001 << i, m);
  endtask

endclass


class gpio_random_seq extends gpio_base_seq;

  `uvm_object_utils(gpio_random_seq)

  int unsigned num_items = 20;

  function new(string name = "gpio_random_seq");
    super.new(name);
  endfunction

  task body();
    gpio_seq_item req;
    bit [31:0] m;

    if ((num_pins == 0) || (num_pins > GPIO_UVC_MAX_WIDTH))
      `uvm_fatal("GPIO_SEQ",
        $sformatf("gpio_random_seq num_pins must be 1..%0d, got %0d",
                  GPIO_UVC_MAX_WIDTH, num_pins))

    m = seq_active_mask();

    repeat (num_items) begin
      req = gpio_seq_item::type_id::create("req");
      start_item(req);

      if (!req.randomize() with { hold_cycles inside {[1:3]}; })
        `uvm_fatal("GPIO_SEQ", "Randomization failed in gpio_random_seq")

      req.mask = m;
      finish_item(req);
    end
  endtask

endclass
