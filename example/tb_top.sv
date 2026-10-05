`timescale 1ns/1ps

module tb_top;

  import uvm_pkg::*;
  import gpio_pkg::*;

  logic clk;

  gpio_if gpio_vif(clk);

  gpio_demo_dut dut (
    .gpio(gpio_vif)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    gpio_vif.rst_n = 1'b0;
    repeat (3) @(posedge clk);
    gpio_vif.rst_n = 1'b1;
  end

  initial begin
    uvm_config_db#(virtual gpio_if)::set(
      null,
      "uvm_test_top",
      "vif",
      gpio_vif
    );

    run_test();
  end

endmodule
