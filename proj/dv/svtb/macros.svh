`ifndef MACROS__SVH
  `define MACROS__SVH

`define WORD        (32)
`define HALF        (16)
`define BYTE        (8)
`define REG_BITS    (5)
`define NUM_REGS    (32)

`define print_uvm_factory(PRINT_ALL_TYPES=1) uvm_factory::get().print(.all_types(PRINT_ALL_TYPES));

`endif