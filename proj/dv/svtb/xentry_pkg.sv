`include "uvm_macros.svh"

package xentry_pkg;
    import uvm_pkg::*;
    import xentry_types::*;

    `include "memory_transaction.sv"
    `include "memory_transaction_sequences.sv"
    `include "memory_sequencer.sv"
    `include "memory_driver.sv"
    `include "memory_monitor.sv"
    `include "memory_agent.sv"
    `include "memory_scoreboard.sv"
    `include "memory_environment.sv"

    `include "tests.sv"
endpackage: xentry_pkg