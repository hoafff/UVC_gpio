`timescale 1ns/1ps

interface gpio_if(input logic clk);

  // Reset is owned by the integrating testbench/DUT wrapper.
  logic        rst_n;

  // Generic GPIO view used by the reusable UVC.
  // gpio_in  : external value driven by the UVC toward DUT inputs.
  // gpio_out : value driven by the DUT toward the external world.
  // gpio_oe  : DUT output-enable/direction indication.
  logic [31:0] gpio_in;
  logic [31:0] gpio_out;
  logic [31:0] gpio_oe;

  clocking drv_cb @(posedge clk);
    default input #1step output #0;
    input  rst_n;
    output gpio_in;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step output #0;
    input rst_n;
    input gpio_in;
    input gpio_out;
    input gpio_oe;
  endclocking

  // A DUT-specific wrapper can expose this modport and map its real pins
  // to these generic UVC signals.
  modport DUT (
    input  clk,
    input  rst_n,
    input  gpio_in,
    output gpio_out,
    output gpio_oe
  );

endinterface
