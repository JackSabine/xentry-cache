module l2_cache import xentry_pkg::*; #(
    parameter LINE_SIZE = 32, // 32 Bytes per block
    parameter CACHE_SIZE = 4096, // Bytes
    parameter ASSOC = 4,
    parameter XLEN = 32 // bits
) (
    input wire clk,
    input wire reset,

    input wire [XLEN-1:0] req_address,
    input wire memory_operation_e req_type,
    input wire req_valid,
    input wire [XLEN-1:0] word_to_store,
    output wire [XLEN-1:0] fetched_word,
    output wire req_fulfilled,

    output wire [XLEN-1:0] memory_req_address,
    output wire memory_operation_e memory_req_type,
    output wire memory_req_valid,
    output wire [XLEN-1:0] memory_word_to_store,
    input wire [XLEN-1:0] memory_fetched_word,
    input wire memory_req_fulfilled
);
wire process_lru_counters;
wire flush_mode;
wire load_mode;
wire clear_selected_dirty_bit;
wire set_selected_dirty_bit;
wire perform_write;
wire clear_selected_valid_bit;
wire finish_new_line_install;
wire set_new_higher_memory_block_address;
wire use_dirty_tag_for_higher_memory_block_address;
wire reset_counter;
wire decrement_counter;

wire counter_done;
wire valid_block_match;
wire valid_dirty_bit;

l2_cache_datapath #(
    .LINE_SIZE(LINE_SIZE),
    .CACHE_SIZE(CACHE_SIZE),
    .ASSOC(ASSOC),
    .XLEN(XLEN)
) datapath (.*);

l2_cache_controller controller (.*);

endmodule