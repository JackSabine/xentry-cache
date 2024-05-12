interface memory_if import xentry_types::*; #(
    parameter XLEN = 32
) (
    input bit clk
);
    logic [XLEN-1:0] address;
    memory_operation_e op;
    memory_operation_size_e size;
    logic [XLEN-1:0] word_to_store;
    logic [XLEN-1:0] fetched_word;
    logic req_valid;
    logic req_fulfilled;
endinterface