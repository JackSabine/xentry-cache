module dcache import xentry_pkg::*; #(
    parameter LINE_SIZE = 32, // 32 Bytes per block
    parameter CACHE_SIZE = 1024, // Bytes
    parameter XLEN = 32 // bits
) (
    input wire clk,
    input wire reset,

    input wire [XLEN-1:0] pipe_req_address,
    input memory_operation_size_e pipe_req_size,
    input memory_operation_e pipe_req_type,
    input wire pipe_req_valid,
    output wire [XLEN-1:0] pipe_word,
    output wire pipe_word_valid,

    output wire [XLEN-1:0] l2_address,
    output wire l2_access,
    input wire [XLEN-1:0] l2_word,
    input wire l2_word_valid
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
wire reset_counter;
wire decrement_counter;
wire counter_done;
wire hit;
wire dirty_miss;
wire clean_miss;

dcache_datapath #(
    .LINE_SIZE(LINE_SIZE),
    .OFS_SIZE(OFS_SIZE),
    .SET_SIZE(SET_SIZE),
    .TAG_SIZE(TAG_SIZE),
    .NUM_SETS(NUM_SETS),
    .XLEN(XLEN)
) datapath (
    .clk(clk),
    .reset(reset),

    .req_ofs(pipe_req_ofs),
    .req_set(pipe_req_set),
    .req_tag(pipe_req_tag),
    .req_size(pipe_req_size),
    .req_type(pipe_req_type),
    .req_valid(pipe_req_valid),
    .req_data_to_store(),
    .req_data_to_return(pipe_word),

    .l2_address(l2_address),
    .data_from_l2(l2_word),
    .data_to_l2(),

    .flush_mode(flush_mode),
    .load_mode(load_mode),
    .clear_selected_dirty_bit(clear_selected_dirty_bit),
    .clear_selected_valid_bit(clear_selected_valid_bit),
    .finish_new_line_install(finish_new_line_install),
    .set_new_l2_block_address(set_new_l2_block_address),
    .reset_counter(reset_counter),
    .decrement_counter(decrement_counter),
    .counter_done(counter_done),
    .hit(hit),
    .dirty_miss(dirty_miss),
    .clean_miss(clean_miss)
);

dcache_controller controller (
    .clk(clk),
    .reset(reset),

    .counter_done(counter_done),
    .hit(hit),
    .dirty_miss(dirty_miss),
    .clean_miss(clean_miss),

    .flush_mode(flush_mode),
    .load_mode(load_mode),
    .clear_selected_dirty_bit(clear_selected_dirty_bit),
    .clear_selected_valid_bit(clear_selected_valid_bit),
    .finish_new_line_install(finish_new_line_install),
    .set_new_l2_block_address(set_new_l2_block_address),
    .reset_counter(reset_counter),
    .decrement_counter(decrement_counter),

    .l2_access(l2_access)
);

assign pipe_word_valid = hit;

endmodule