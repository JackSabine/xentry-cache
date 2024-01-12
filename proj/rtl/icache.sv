module icache import xentry_pkg::*; #(
    parameter LINE_SIZE = 32, // 32 Bytes per block
    parameter CACHE_SIZE = 1024, // Bytes
    parameter XLEN = 32 // bits
) (
    input wire clk,
    input wire reset,

    input wire [XLEN-1:0] pipe_req_address,
    input wire icache_memory_operation_e pipe_req_type,
    input wire pipe_req_valid,
    output wire [XLEN-1:0] pipe_fetched_word,
    output wire pipe_req_fulfilled,

    output wire [XLEN-1:0] l2_req_address,
    output wire memory_operation_e l2_req_type,
    output wire l2_req_valid,
    input wire [XLEN-1:0] l2_fetched_word,
    input wire l2_req_fulfilled
);

///////////////////////////////////////////////////////////////////
//                 controller <-> datapath signals               //
///////////////////////////////////////////////////////////////////
wire load_mode;
wire perform_write;
wire clear_selected_valid_bit;
wire finish_new_line_install;
wire set_new_l2_block_address;
wire reset_counter;
wire decrement_counter;
wire counter_done;
wire valid_block_match;

icache_datapath #(
    .LINE_SIZE(LINE_SIZE),
    .CACHE_SIZE(CACHE_SIZE),
    .XLEN(XLEN)
) datapath (.*);

icache_controller controller (.*);

endmodule