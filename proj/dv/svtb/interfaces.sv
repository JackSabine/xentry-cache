interface cache_if import xentry_types::*; #(
    parameter XLEN = 32
) (
    input bit clk
);
    logic [XLEN-1:0] req_address;
    memory_operation_e req_operation;
    memory_operation_size_e req_size;
    logic [XLEN-1:0] req_store_word;
    logic req_valid;

    logic [XLEN-1:0] req_loaded_word;
    logic req_fulfilled;
endinterface

interface higher_memory_if import xentry_types::*; #(
    parameter XLEN = 32
) (
    input bit clk
);
    logic [XLEN-1:0] req_address;
    memory_operation_e req_operation;
    logic [XLEN-1:0] req_store_word;
    logic req_valid;

    logic [XLEN-1:0] req_loaded_word;
    logic req_fulfilled;
endinterface

interface reset_if (
    input bit clk
);
    logic reset;
endinterface
