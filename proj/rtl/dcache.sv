module dcache #(
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

wire [OFS_SIZE-1:0] req_ofs;
wire [SET_SIZE-1:0] req_set;
wire [TAG_SIZE-1:0] req_tag;

assign req_ofs = pipe_address[OFS_POS +: OFS_SIZE];
assign req_set = pipe_address[SET_POS +: SET_SIZE];
assign req_tag = pipe_address[TAG_POS +: TAG_SIZE];

///////////////////////////////////////////////////////////////////
//                 controller <-> datapath signals               //
///////////////////////////////////////////////////////////////////


endmodule