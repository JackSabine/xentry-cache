module l2_cache import xentry_pkg::*; #(
    parameter LINE_SIZE = 32, // 32 Bytes per block
    parameter XLEN = 32 // bits
) (
    input wire clk,
    input wire reset,

    input wire [XLEN-1:0] icache_req_address,
    input wire memory_operation_e icache_req_type,
    input wire icache_req_valid,
    output wire [XLEN-1:0] icache_fetched_word,
    output wire icache_req_fulfilled,

    input wire [XLEN-1:0] dcache_req_address,
    input wire memory_operation_e dcache_req_type,
    input wire dcache_req_valid,
    input wire [XLEN-1:0] dcache_word_to_store,
    output wire [XLEN-1:0] dcache_fetched_word,
    output wire dcache_req_fulfilled,

    output wire [XLEN-1:0] memory_req_address,
    output wire memory_operation_e memory_req_type,
    output wire memory_req_valid,
    output wire [XLEN-1:0] memory_word_to_store,
    input wire [XLEN-1:0] memory_fetched_word,
    input wire memory_req_fulfilled
);

endmodule