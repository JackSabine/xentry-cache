module dcache_datapath import xentry_pkg::*; #(
    parameter LINE_SIZE = 32, // 32 Bytes per block
    parameter OFS_SIZE = 0,
    parameter SET_SIZE = 0,
    parameter TAG_SIZE = 0,
    parameter NUM_SETS = 0,
    parameter XLEN = 32

) (
    //// TOP LEVEL ////
    input wire clk,
    input wire reset,

    //// PIPELINE ////
    input wire [OFS_SIZE-1:0] pipe_req_ofs,
    input wire [SET_SIZE-1:0] pipe_req_set,
    input wire [TAG_SIZE-1:0] pipe_req_tag,
    input wire memory_operation_size_e pipe_req_size,
    input wire memory_operation_e pipe_req_type,
    input wire pipe_req_valid,
    input wire [XLEN-1:0] pipe_word_to_store,
    output logic [XLEN-1:0] pipe_fetched_word,

    //// HIGHER MEMORY ////
    output wire [XLEN-1:0] l2_req_address,
    input wire [XLEN-1:0] l2_fetched_word,
    output logic [XLEN-1:0] l2_word_to_store,

    //// DATAPATH/CONTROLLER SIGNALS ////
    input wire flush_mode,
    input wire load_mode,
    input wire clear_selected_dirty_bit,
    input wire clear_selected_valid_bit,
    input wire finish_new_line_install,
    input wire set_new_l2_block_address,
    input wire reset_counter,
    input wire decrement_counter,

    output wire counter_done,
    output logic hit,
    output logic dirty_miss,
    output logic clean_miss
);

///////////////////////////////////////////////////////////////////
//                        Setup variables                        //
///////////////////////////////////////////////////////////////////
localparam BYTES_PER_WORD = XLEN / 8;
localparam WORDS_PER_LINE = LINE_SIZE / BYTES_PER_WORD;
localparam BYTE_SELECT_SIZE = $clog2(BYTES_PER_WORD);
localparam WORD_SELECT_SIZE = OFS_SIZE - BYTE_SELECT_SIZE;

///////////////////////////////////////////////////////////////////
//                    Cache memory structures                    //
///////////////////////////////////////////////////////////////////
logic [NUM_SETS-1:0] valid_array, dirty_array;
logic [NUM_SETS-1:0][TAG_SIZE-1:0] tag_array;
logic [NUM_SETS-1:0][WORDS_PER_LINE-1:0][BYTES_PER_WORD-1:0][7:0] data_lines;

///////////////////////////////////////////////////////////////////
//                   Implementation structures                   //
///////////////////////////////////////////////////////////////////
logic [WORD_SELECT_SIZE-1:0] counter;

wire [WORD_SELECT_SIZE-1:0] pipe_req_word_select, r_word_select, w_word_select;
wire [BYTE_SELECT_SIZE-1:0] pipe_req_byte_select, r_byte_select, w_byte_select;
memory_operation_size_e op_size;
memory_operation_e op_type;

logic tag_match;

logic [WORDS_PER_LINE-1:0][BYTES_PER_WORD-1:0][7:0] single_data_line;
logic [BYTES_PER_WORD-1:0][7:0] r_data;
logic [BYTES_PER_WORD-1:0][7:0] read_bus;

logic [NUM_SETS-1:0][WORDS_PER_LINE-1:0] w_word_active;
logic [BYTES_PER_WORD-1:0] w_byte_active;
logic [BYTES_PER_WORD-1:0][7:0] write_bus;
logic [BYTES_PER_WORD-1:0][7:0] w_data;

logic [XLEN-OFS_SIZE-1:0] l2_block_address;

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
assign {pipe_req_word_select, pipe_req_byte_select} = pipe_req_ofs;
assign r_word_select = flush_mode ? counter : pipe_req_word_select;
assign w_word_select = load_mode ? counter : pipe_req_word_select;
assign r_byte_select = flush_mode ? {BYTE_SELECT_SIZE{1'b0}} : pipe_req_byte_select;
assign w_byte_select = load_mode ? {BYTE_SELECT_SIZE{1'b0}} : pipe_req_byte_select;

always_comb begin
    if (load_mode || flush_mode) op_size = WORD;
    else                         op_size = pipe_req_size;

    if (pipe_req_valid) op_type = pipe_req_type;
    else           op_type = LOAD;
end

///////////////////////////////////////////////////////////////////
//                    Cache metadata logic                       //
///////////////////////////////////////////////////////////////////
always_ff @(posedge clk) begin
    if (reset) begin
        for (int i_set = 0; i_set < NUM_SETS; i_set = i_set + 1) begin
            valid_array[i_set] <= 1'b0;
        end
    end else begin
        if (clear_selected_valid_bit) begin
            valid_array[pipe_req_set] <= 1'b0;
        end else if (finish_new_line_install) begin
            valid_array[pipe_req_set] <= 1'b1;
            tag_array[pipe_req_set] <= pipe_req_tag;
        end

        for (int i_set = 0; i_set < NUM_SETS; i_set = i_set + 1) begin
            if (i_set == pipe_req_set && clear_selected_dirty_bit) begin
                // Clear selected dirty bit with higher priority
                dirty_array[pipe_req_set] <= 1'b0;
            end else if (|w_word_active[i_set] && load_mode == 1'b0) begin
                // Only set dirty bit if a write active line is high and we aren't loading from L2
                dirty_array[i_set] <= 1'b1;
            end
        end
    end
end

///////////////////////////////////////////////////////////////////
//                       Hit/miss logic                          //
///////////////////////////////////////////////////////////////////
always_comb begin
    {hit, clean_miss, dirty_miss} = 3'b000;

    tag_match = tag_array[pipe_req_set] == pipe_req_tag;

    if (pipe_req_valid) begin
        // tag_match and dirty_array[...] are allowed to be x
        casex({valid_array[pipe_req_set], tag_match, dirty_array[pipe_req_set]})
        3'b0??: clean_miss = 1'b1;
        3'b100: clean_miss = 1'b1;
        3'b101: dirty_miss = 1'b1;
        3'b11?: hit = 1'b1;
        default: {hit, clean_miss, dirty_miss} = 3'bxxx;
        endcase
    end
end


///////////////////////////////////////////////////////////////////
//                     Cacheline read logic                      //
///////////////////////////////////////////////////////////////////
logic [7:0] byte_read;
logic [15:0] half_read;
logic [31:0] word_read;

always_comb begin
    single_data_line = data_lines[pipe_req_set];
    read_bus = single_data_line[r_word_select];

    byte_read = read_bus[r_byte_select];
    half_read = r_byte_select[1] ? {read_bus[3], read_bus[2]} : {read_bus[1], read_bus[0]};
    word_read = read_bus;

    case (op_size)
    BYTE: r_data = {'0, byte_read};
    HALF: r_data = {'0, half_read};
    WORD: r_data = {'0, word_read};
    default: r_data = 'x;
    endcase

    pipe_fetched_word = r_data;
    l2_word_to_store = read_bus;
end

///////////////////////////////////////////////////////////////////
//                     Cacheline write logic                     //
///////////////////////////////////////////////////////////////////
always_comb begin : write_active_logic
    for (int i_set = 0; i_set < NUM_SETS; i_set = i_set + 1) begin
        for (int i_word = 0; i_word < WORDS_PER_LINE; i_word = i_word + 1) begin
            w_word_active[i_set][i_word] =
                (pipe_req_set == i_set) & // This set is selected
                (w_word_select == i_word) & // This word is selected
                ((hit & op_type == STORE) | load_mode); // A hit and a store OR just load_mode
        end
    end

    for (int i_byte = 0; i_byte < BYTES_PER_WORD; i_byte++) begin
        w_byte_active[i_byte] = 1'b0;
    end

    case (op_size)
    BYTE: begin
        w_byte_active[w_byte_select] = 1'b1;
    end

    HALF: begin
        if (|w_byte_select[0:0] == 1'b0) begin
            for (int i_byte = 0; i_byte < 2; i_byte++) begin
                w_byte_active[w_byte_select + i_byte] = 1'b1;
            end
        end
    end

    WORD: begin
        if (|w_byte_select[1:0] == 1'b0) begin
            for (int i_byte = 0; i_byte < BYTES_PER_WORD; i_byte++) begin
                w_byte_active[i_byte] = 1'b1;
            end
        end
    end

    default: w_byte_active = 'x;
    endcase

end : write_active_logic

always_comb begin : write_bus_logic
    w_data = load_mode ? l2_fetched_word : pipe_word_to_store;

    // B0
    write_bus[0] = w_data[0];

    // B1
    if (op_size == BYTE) write_bus[1] = w_data[0];
    else                 write_bus[1] = w_data[1];

    // B2
    if (op_size == WORD) write_bus[2] = w_data[2];
    else                 write_bus[2] = w_data[0];

    // B3
    unique case (op_size)
    BYTE: write_bus[3] = w_data[0];
    HALF: write_bus[3] = w_data[1];
    WORD: write_bus[3] = w_data[3];
    default: write_bus[3] = 'x;
    endcase
end

always_ff @(posedge clk) begin
    for (int i_set = 0; i_set < NUM_SETS; i_set = i_set + 1) begin
        for (int i_word = 0; i_word < WORDS_PER_LINE; i_word = i_word + 1) begin
            for (int i_byte = 0; i_byte < BYTES_PER_WORD; i_byte = i_byte + 1) begin
                if (w_word_active[i_set][i_word] & w_byte_active[i_byte]) begin
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
            dirty_miss ? tag_array[pipe_req_set] : pipe_req_tag,
            pipe_req_set
        };
    end
end

assign l2_req_address = {l2_block_address, counter, {BYTE_SELECT_SIZE{1'b0}}};

endmodule
