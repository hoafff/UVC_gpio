module gpio_demo_dut(gpio_if.DUT gpio);

  // Small combinational loopback used only to demonstrate integration.
  // This module is NOT part of the reusable UVC.
  assign gpio.gpio_out = gpio.gpio_in;
  assign gpio.gpio_oe  = 32'hFFFF_FFFF;

endmodule
