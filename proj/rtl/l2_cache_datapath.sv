`include "macros.svh"

module l2_cache_datapath import xentry_pkg::*; #(
    parameter LINE_SIZE = 32, // 32 Bytes per block
    parameter CACHE_SIZE = 1024,
    parameter ASSOC = 4,
    parameter XLEN = 32
) (
    //// TOP LEVEL ////
    input wire clk,
    input wire reset,

    //// REQUESTER ////
    input wire [XLEN-1:0] req_address,
    input wire [XLEN-1:0] word_to_store,
    output logic [XLEN-1:0] fetched_word,

    //// HIGHER MEMORY ////
    output wire [XLEN-1:0] memory_req_address,
    input wire [XLEN-1:0] memory_fetched_word,
    output logic [XLEN-1:0] memory_word_to_store,

    //// DATAPATH/CONTROLLER SIGNALS ////
    input wire process_lru_counters,
    input wire flush_mode,
    input wire load_mode,
    input wire clear_selected_dirty_bit,
    input wire set_selected_dirty_bit,
    input wire perform_write,
    input wire clear_selected_valid_bit,
    input wire finish_new_line_install,
    input wire set_new_higher_memory_block_address,
    input wire use_dirty_tag_for_higher_memory_block_address,
    input wire reset_counter,
    input wire decrement_counter,

    output wire counter_done,
    output logic valid_block_match,
    output logic valid_dirty_bit
);

generate;
    if ((LINE_SIZE % 4 != 0)  || (CACHE_SIZE % 4 != 0)) $error("LINE_SIZE (", LINE_SIZE, ") and CACHE_SIZE (", CACHE_SIZE, ") MUST BE DIVISIBLE BY 4");
    if (LINE_SIZE > CACHE_SIZE) $error("LINE_SIZE (", LINE_SIZE, ") MAY NOT EXCEED CACHE_SIZE (", CACHE_SIZE, ")");
    if (XLEN != `WORD) $error("XLEN VALUES OTHER THAN `WORD (", `WORD, ") ARE NOT SUPPORTED", );
endgenerate

///////////////////////////////////////////////////////////////////
//                        Setup variables                        //
///////////////////////////////////////////////////////////////////
localparam NUM_SETS = CACHE_SIZE / (LINE_SIZE * ASSOC);

localparam OFS_SIZE = $clog2(LINE_SIZE),
           SET_SIZE = $clog2(NUM_SETS),
           TAG_SIZE = XLEN - (SET_SIZE + OFS_SIZE);

localparam OFS_POS = 0,
           SET_POS = OFS_POS + OFS_SIZE,
           TAG_POS = SET_POS + SET_SIZE;

localparam BYTES_PER_WORD = `WORD / `BYTE;
localparam WORDS_PER_LINE = LINE_SIZE / BYTES_PER_WORD;
localparam BYTE_SELECT_SIZE = $clog2(BYTES_PER_WORD);
localparam WORD_SELECT_SIZE = OFS_SIZE - BYTE_SELECT_SIZE;

localparam ASSOC_WIDTH = $clog2(ASSOC);

///////////////////////////////////////////////////////////////////
//                    Cache memory structures                    //
///////////////////////////////////////////////////////////////////
logic [NUM_SETS-1:0][ASSOC-1:0] valid_array, dirty_array;
logic [NUM_SETS-1:0][ASSOC-1:0][TAG_SIZE-1:0] tag_array;
logic [NUM_SETS-1:0][ASSOC-1:0][ASSOC_WIDTH-1:0] lru_array;
logic [NUM_SETS-1:0][ASSOC-1:0][WORDS_PER_LINE-1:0][`WORD-1:0] data_lines;

///////////////////////////////////////////////////////////////////
//                   Implementation structures                   //
///////////////////////////////////////////////////////////////////
logic [WORD_SELECT_SIZE-1:0] counter;

logic tag_match;

logic [NUM_SETS-1:0] w_set_active;
logic [ASSOC-1:0] w_way_active;
logic [WORDS_PER_LINE-1:0] w_word_active;
logic [`WORD-1:0] write_bus;

logic [XLEN-OFS_SIZE-1:0] memory_block_address;

wire [OFS_SIZE-1:0] req_ofs;
wire [SET_SIZE-1:0] req_set;
wire [TAG_SIZE-1:0] req_tag;
wire [WORD_SELECT_SIZE-1:0] req_word_select;

wire [WORD_SELECT_SIZE-1:0] word_select;

wire [ASSOC_WIDTH-1:0] selected_way;

logic [ASSOC-1:0] tag_comparisons;
logic [ASSOC-1:0] one_hot_valid_block_matches;
wire [ASSOC_WIDTH-1:0] matching_way;

wire [ASSOC_WIDTH-1:0] selected_way_lru_counter;

logic [ASSOC-1:0] one_hot_victim_way;
wire [ASSOC_WIDTH-1:0] victim_way;

logic [ASSOC-1:0][XLEN-1:0] words_read;

///////////////////////////////////////////////////////////////////
//                        Steering logic                         //
///////////////////////////////////////////////////////////////////
assign word_select = (flush_mode | load_mode) ? counter : req_word_select;
assign selected_way = (flush_mode | load_mode) ? victim_way : matching_way;

///////////////////////////////////////////////////////////////////
//                    Address decomposition                      //
///////////////////////////////////////////////////////////////////

assign req_ofs = req_address[OFS_POS +: OFS_SIZE];
assign req_set = req_address[SET_POS +: SET_SIZE];
assign req_tag = req_address[TAG_POS +: TAG_SIZE];

assign req_word_select = req_ofs[BYTE_SELECT_SIZE +: WORD_SELECT_SIZE];

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
//                    Cache metadata logic                       //
///////////////////////////////////////////////////////////////////
always_ff @(posedge clk) begin
    if (reset) begin
        valid_array <= '0;
    end else begin
        unique0 if (clear_selected_valid_bit) begin
            valid_array[req_set][selected_way] <= 1'b0;
        end else if (finish_new_line_install) begin
            valid_array[req_set][selected_way] <= 1'b1;
            tag_array[req_set][selected_way] <= req_tag;
        end

        unique0 if (clear_selected_dirty_bit) begin
            dirty_array[req_set][selected_way] <= 1'b0;
        end else if (set_selected_dirty_bit) begin
            dirty_array[req_set][selected_way] <= 1'b1;
        end
    end
end

///////////////////////////////////////////////////////////////////
//                       Hit/miss logic                          //
///////////////////////////////////////////////////////////////////
assign valid_block_match = |one_hot_valid_block_matches;

always_comb begin
    valid_dirty_bit = valid_array[req_set][selected_way] & dirty_array[req_set][selected_way];
end

NO_MORE_THAN_ONE_BLOCK_MATCH: assert property (
    @(posedge clk) disable iff (reset)
    $onehot0(one_hot_valid_block_matches)
);

always_comb begin
    for (int i = 0; i < ASSOC; i++) begin
        tag_comparisons[i] = (tag_array[req_set] == req_tag);

        one_hot_valid_block_matches[i] = valid_array[req_set][i] & tag_comparisons[i];
    end
end

onehot0_to_binary #(
    .ONEHOT_WIDTH(ASSOC_WIDTH)
) matching_block_converter (
    .onehot0(one_hot_valid_block_matches),
    .binary(matching_way)
);

///////////////////////////////////////////////////////////////////
//                         Read logic                            //
///////////////////////////////////////////////////////////////////
always_comb begin
    for (int i = 0; i < ASSOC; i++) begin
        words_read[i] = data_lines[req_set][i][req_word_select];
    end

    fetched_word = words_read[selected_way];
    memory_word_to_store = fetched_word;
end

///////////////////////////////////////////////////////////////////
//                         Write logic                           //
///////////////////////////////////////////////////////////////////
always_comb begin : w_set_active_logic
    for (int s = 0; s < NUM_SETS; s++) begin
        w_set_active[s] = (req_set == s);
    end
end

always_comb begin : w_way_active_logic
    for (int w = 0; w < ASSOC; w++) begin
        // Writing is always done on a present block, so don't need to use selected_way
        w_way_active[w] = (matching_way == w);
    end
end

always_comb begin : w_word_active_logic
    for (int w = 0; w < WORDS_PER_LINE; w++) begin
        w_word_active[w] = (word_select == w);
    end
end

always_comb begin : write_bus_logic
    write_bus = load_mode ? memory_fetched_word : word_to_store;
end

always_ff @(posedge clk) begin
    for (int set = 0; set < NUM_SETS; set++) begin
        for (int way = 0; way < ASSOC; way++) begin
            for (int word = 0; word < WORDS_PER_LINE; word++) begin
                // The controller will block write attempts that are misses
                if (perform_write & w_set_active[set] & w_way_active[way] & w_word_active[word]) begin
                    data_lines[set][way][word] <= write_bus;
                end
            end
        end
    end
end

///////////////////////////////////////////////////////////////////
//                         LRU logic                             //
///////////////////////////////////////////////////////////////////
always_ff @(posedge clk) begin
    if (reset) begin
        for (int s = 0; s < NUM_SETS; s++) begin
            for (int w = 0; w < ASSOC; w++) begin
                lru_array[s][w] <= ASSOC_WIDTH'(w);
            end
        end
    end else begin
        if (process_lru_counters) begin
            for (int i = 0; i < ASSOC; i++) begin
                unique0 if (selected_way_lru_counter > lru_array[req_set][i]) begin
                    lru_array[req_set][i] <= lru_array[req_set][i] + 1;
                end else if (selected_way == i) begin
                    lru_array[req_set][i] <= '0;
                end
            end
        end
    end
end

assign selected_way_lru_counter = lru_array[req_set][selected_way];

NO_MORE_THAN_ONE_WAY_IS_LRU: assert property (
    @(posedge clk) disable iff (reset)
    $onehot(one_hot_victim_way)
);

always_comb begin
    for (int i = 0; i < ASSOC; i++) begin
        one_hot_victim_way[i] = lru_array[req_set][i] == '1;
    end
end

onehot0_to_binary #(
    .ONEHOT_WIDTH(ASSOC_WIDTH)
) victim_way_converter (
    .onehot0(one_hot_victim_way),
    .binary(victim_way)
);

///////////////////////////////////////////////////////////////////
//                  Higher memory address logic                  //
///////////////////////////////////////////////////////////////////
always_ff @(posedge clk) begin
    if (set_new_higher_memory_block_address) begin
        memory_block_address <= {
            use_dirty_tag_for_higher_memory_block_address ? tag_array[req_set][selected_way] : req_tag,
            req_set
        };
    end
end

assign memory_req_address = {memory_block_address, counter, {BYTE_SELECT_SIZE{1'b0}}};

endmodule
