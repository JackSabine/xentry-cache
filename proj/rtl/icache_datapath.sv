`include "macros.svh"

module icache_datapath import xentry_types::*; #(
    parameter LINE_SIZE = 32, // 32 Bytes per block
    parameter CACHE_SIZE = 1024,
    parameter XLEN = 32
) (
    //// TOP LEVEL ////
    input wire clk,
    input wire reset,

    //// PIPELINE ////
    input wire [XLEN-1:0] pipe_req_address,
    output logic [XLEN-1:0] pipe_fetched_word,

    //// HIGHER MEMORY ////
    output wire [XLEN-1:0] l2_req_address,
    input wire [XLEN-1:0] l2_fetched_word,

    //// DATAPATH/CONTROLLER SIGNALS ////
    input wire load_mode,
    input wire perform_write,
    input wire clear_selected_valid_bit,
    input wire finish_new_line_install,
    input wire set_new_l2_block_address,
    input wire reset_counter,
    input wire decrement_counter,

    output wire counter_done,
    output logic valid_block_match
);

generate;
    if ((LINE_SIZE % 4 != 0)  || (CACHE_SIZE % 4 != 0)) $error("LINE_SIZE (", LINE_SIZE, ") and CACHE_SIZE (", CACHE_SIZE, ") MUST BE DIVISIBLE BY 4");
    if (LINE_SIZE > CACHE_SIZE) $error("LINE_SIZE (", LINE_SIZE, ") MAY NOT EXCEED CACHE_SIZE (", CACHE_SIZE, ")");
    if (XLEN != `WORD) $error("XLEN VALUES OTHER THAN `WORD (", `WORD, ") ARE NOT SUPPORTED", );
endgenerate

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

localparam BYTES_PER_WORD = `WORD / `BYTE;
localparam HALFS_PER_WORD = `WORD / `HALF;
localparam WORDS_PER_LINE = LINE_SIZE / BYTES_PER_WORD;
localparam BYTE_SELECT_SIZE = $clog2(BYTES_PER_WORD);
localparam WORD_SELECT_SIZE = OFS_SIZE - BYTE_SELECT_SIZE;

///////////////////////////////////////////////////////////////////
//                    Cache memory structures                    //
///////////////////////////////////////////////////////////////////
logic [NUM_SETS-1:0] valid_array;
logic [NUM_SETS-1:0][TAG_SIZE-1:0] tag_array;
logic [NUM_SETS-1:0][WORDS_PER_LINE-1:0][BYTES_PER_WORD-1:0][`BYTE-1:0] data_lines;

///////////////////////////////////////////////////////////////////
//                   Implementation structures                   //
///////////////////////////////////////////////////////////////////
logic [WORD_SELECT_SIZE-1:0] counter;

wire [WORD_SELECT_SIZE-1:0] pipe_req_word_select, word_select;

logic tag_match;

logic [`BYTE-1:0] byte_read;
logic [`HALF-1:0] half_read;
logic [`WORD-1:0] word_read;

logic [WORDS_PER_LINE-1:0][BYTES_PER_WORD-1:0][`BYTE-1:0] selected_data_line;
logic [BYTES_PER_WORD-1:0][`BYTE-1:0] zext_sized_read_data;

logic [`WORD-1:0] word_write;

logic [NUM_SETS-1:0] w_set_active;
logic [WORDS_PER_LINE-1:0] w_word_active;
logic [BYTES_PER_WORD-1:0][`BYTE-1:0] write_bus;

logic [XLEN-OFS_SIZE-1:0] l2_block_address;

wire [OFS_SIZE-1:0] pipe_req_ofs;
wire [SET_SIZE-1:0] pipe_req_set;
wire [TAG_SIZE-1:0] pipe_req_tag;

///////////////////////////////////////////////////////////////////
//                    Address decomposition                      //
///////////////////////////////////////////////////////////////////

assign pipe_req_ofs = pipe_req_address[OFS_POS +: OFS_SIZE];
assign pipe_req_set = pipe_req_address[SET_POS +: SET_SIZE];
assign pipe_req_tag = pipe_req_address[TAG_POS +: TAG_SIZE];

///////////////////////////////////////////////////////////////////
//                        Counter logic                          //
///////////////////////////////////////////////////////////////////
assign counter_done = (counter == 'd0);

always_ff @(posedge clk) begin
    if (reset_counter) begin
        counter <= {WORD_SELECT_SIZE{1'b1}};
    end else if (decrement_counter) begin
        counter <= counter - WORD_SELECT_SIZE'('d1);
    end
end

///////////////////////////////////////////////////////////////////
//                        Steering logic                         //
///////////////////////////////////////////////////////////////////
assign pipe_req_word_select = pipe_req_ofs[BYTE_SELECT_SIZE +: WORD_SELECT_SIZE];
assign word_select = (load_mode) ? counter : pipe_req_word_select;

///////////////////////////////////////////////////////////////////
//                    Cache metadata logic                       //
///////////////////////////////////////////////////////////////////
always_ff @(posedge clk) begin
    if (reset) begin
        for (int i_set = 0; i_set < NUM_SETS; i_set = i_set + 1) begin
            valid_array[i_set] <= 1'b0;
        end
    end else begin
        unique0 if (clear_selected_valid_bit) begin
            valid_array[pipe_req_set] <= 1'b0;
        end else if (finish_new_line_install) begin
            valid_array[pipe_req_set] <= 1'b1;
            tag_array[pipe_req_set] <= pipe_req_tag;
        end
    end
end

///////////////////////////////////////////////////////////////////
//                       Hit/miss logic                          //
///////////////////////////////////////////////////////////////////
always_comb begin
    tag_match = tag_array[pipe_req_set] == pipe_req_tag;

    valid_block_match = valid_array[pipe_req_set] & tag_match;
end


///////////////////////////////////////////////////////////////////
//                     Cacheline read logic                      //
///////////////////////////////////////////////////////////////////
always_comb begin
    selected_data_line = data_lines[pipe_req_set];
    zext_sized_read_data = selected_data_line[word_select];

    pipe_fetched_word = zext_sized_read_data;
end

///////////////////////////////////////////////////////////////////
//                     Cacheline write logic                     //
///////////////////////////////////////////////////////////////////
always_comb begin : w_set_active_logic
    for (int i_set = 0; i_set < NUM_SETS; i_set = i_set + 1) begin
        w_set_active[i_set] = pipe_req_set == i_set;
    end
end

always_comb begin : w_word_active_logic
    for (int i_word = 0; i_word < WORDS_PER_LINE; i_word = i_word + 1) begin
        w_word_active[i_word] = word_select == i_word;
    end
end

always_comb begin : write_bus_logic
    write_bus = l2_fetched_word;
end

always_ff @(posedge clk) begin
    for (int i_set = 0; i_set < NUM_SETS; i_set = i_set + 1) begin
        for (int i_word = 0; i_word < WORDS_PER_LINE; i_word = i_word + 1) begin
            for (int i_byte = 0; i_byte < BYTES_PER_WORD; i_byte = i_byte + 1) begin
                if (perform_write & w_set_active[i_set] & w_word_active[i_word]) begin
                    data_lines[i_set][i_word][i_byte] <= write_bus[i_byte];
                end
            end
        end
    end
end

///////////////////////////////////////////////////////////////////
//                  Higher cache address logic                   //
///////////////////////////////////////////////////////////////////
always_ff @(posedge clk) begin
    if (set_new_l2_block_address) begin
        l2_block_address <= {
            pipe_req_tag,
            pipe_req_set
        };
    end
end

assign l2_req_address = {l2_block_address, counter, {BYTE_SELECT_SIZE{1'b0}}};

endmodule
