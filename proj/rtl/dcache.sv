module dcache import xentry_pkg::*; #(
    parameter LINE_SIZE = 32, // 32 Bytes per block
    parameter CACHE_SIZE = 1024, // Bytes
    parameter XLEN = 32 // bits
) (
    input wire clk,
    input wire reset,

    input wire [XLEN-1:0] pipe_req_address,
    input wire memory_operation_size_e pipe_req_size,
    input wire memory_operation_e pipe_req_type,
    input wire pipe_req_valid,
    input wire [XLEN-1:0] pipe_word_to_store,
    output wire [XLEN-1:0] pipe_fetched_word,
    output wire pipe_req_fulfilled,

    output wire [XLEN-1:0] l2_req_address,
    output wire memory_operation_e l2_req_type,
    output wire l2_req_valid,
    output wire [XLEN-1:0] l2_word_to_store,
    input wire [XLEN-1:0] l2_fetched_word,
    input wire l2_req_fulfilled
);

///////////////////////////////////////////////////////////////////
//                        Setup variables                        //
///////////////////////////////////////////////////////////////////
localparam NUM_SETS = CACHE_SIZE / (LINE_SIZE);

localparam OFS_SIZE = $clog2(LINE_SIZE),
           SET_SIZE = $clog2(NUM_SETS),
           TAG_SIZE = XLEN - (SET_SIZE + OFS_SIZE);

localparam OFS_POS = 0,
           SET_POS = OFS_POS + OFS_SIZE,
           TAG_POS = SET_POS + SET_SIZE;

wire [OFS_SIZE-1:0] pipe_req_ofs;
wire [SET_SIZE-1:0] pipe_req_set;
wire [TAG_SIZE-1:0] pipe_req_tag;

assign pipe_req_ofs = pipe_req_address[OFS_POS +: OFS_SIZE];
assign pipe_req_set = pipe_req_address[SET_POS +: SET_SIZE];
assign pipe_req_tag = pipe_req_address[TAG_POS +: TAG_SIZE];

///////////////////////////////////////////////////////////////////
//                 controller <-> datapath signals               //
///////////////////////////////////////////////////////////////////
wire flush_mode;
wire load_mode;
wire clear_selected_dirty_bit;
wire clear_selected_valid_bit;
wire finish_new_line_install;
wire set_new_l2_block_address;
wire use_dirty_tag_for_l2_block_address;
wire reset_counter;
wire decrement_counter;
wire counter_done;
wire hit;
wire valid_dirty_bit;
wire miss;
wire clflush_requested;

dcache_datapath #(
    .LINE_SIZE(LINE_SIZE),
    .OFS_SIZE(OFS_SIZE),
    .SET_SIZE(SET_SIZE),
    .TAG_SIZE(TAG_SIZE),
    .NUM_SETS(NUM_SETS),
    .XLEN(XLEN)
) datapath (.*);

dcache_controller controller (.*);

endmodule