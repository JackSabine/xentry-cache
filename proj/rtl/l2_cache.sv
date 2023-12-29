module l2_cache #(
    parameter LINE_SIZE = 32, // 32 Bytes per block
    parameter XLEN = 32 // bits
) (
    input wire clk,
    input wire reset,

    input wire [XLEN-1:0] dcache_address,
    input wire dcache_access,
    output wire [XLEN-1:0] dcache_word,
    output wire [XLEN-1:0] dcache_word_valid,

    input wire [XLEN-1:0] icache_address,
    input wire icache_access,
    output wire [XLEN-1:0] icache_word,
    output wire [XLEN-1:0] icache_word_valid,

    output wire [XLEN-1:0] memory_address,
    output wire memory_access,
    input wire [XLEN-1:0] memory_word,
    input wire memory_word_valid
);

endmodule