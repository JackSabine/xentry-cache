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
    input wire [OFS_SIZE-1:0] req_ofs,
    input wire [SET_SIZE-1:0] req_set,
    input wire [TAG_SIZE-1:0] req_tag,
    input memory_operation_size_e req_size,
    input memory_operation_e req_type,
    input wire req_valid,
    input wire [XLEN-1:0] req_data_to_store,
    output logic [XLEN-1:0] req_data_to_return,

    //// HIGHER MEMORY ////
    output wire [XLEN-1:0] l2_address,
    input wire [XLEN-1:0] data_from_l2,
    output logic [XLEN-1:0] data_to_l2,

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
//                        Counter logic                          //
///////////////////////////////////////////////////////////////////
logic [WORD_SELECT_SIZE-1:0] counter;

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
wire [WORD_SELECT_SIZE-1:0] req_word_select, r_word_select, w_word_select;
wire [BYTE_SELECT_SIZE-1:0] req_byte_select, w_byte_select;
memory_operation_size_e op_size;
memory_operation_e op_type;

assign {req_word_select, req_byte_select} = req_ofs;
assign r_word_select = flush_mode ? counter : req_word_select;
assign w_word_select = load_mode ? counter : req_word_select;
assign w_byte_select = load_mode ? {BYTE_SELECT_SIZE{1'b0}} : req_byte_select;

always_comb begin
    if (load_mode || flush_mode) op_size = WORD;
    else                         op_size = req_size;

    if (req_valid) op_type = req_type;
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
        if (clear_selected_dirty_bit) begin
            dirty_array[req_set] <= 1'b0;
        end


        if (clear_selected_valid_bit) begin
            valid_array[req_set] <= 1'b0;
        end else if (finish_new_line_install) begin
            valid_array[req_set] <= 1'b1;
            tag_array[req_set] <= req_tag;
        end
    end
end

///////////////////////////////////////////////////////////////////
//                       Hit/miss logic                          //
///////////////////////////////////////////////////////////////////
logic tag_match;

always_comb begin
    {hit, clean_miss, dirty_miss} = 3'b000;

    tag_match = tag_array[req_set] == req_tag;

    if (req_valid) begin
        casex({valid_array[req_set], tag_match, dirty_array[req_set]})
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
logic [WORDS_PER_LINE-1:0][BYTES_PER_WORD-1:0][7:0] single_data_line;
logic [BYTES_PER_WORD-1:0][7:0] line_word;

always_comb begin
    single_data_line = data_lines[req_set];
    line_word = single_data_line[r_word_select];

    req_data_to_return = line_word;
    data_to_l2 = line_word;
end

///////////////////////////////////////////////////////////////////
//                     Cacheline write logic                     //
///////////////////////////////////////////////////////////////////
logic [NUM_SETS-1:0][WORDS_PER_LINE-1:0] w_active;
logic [BYTES_PER_WORD-1:0][7:0] write_bus;
logic [BYTES_PER_WORD-1:0][7:0] w_data;

always_comb begin : write_active_logic
    for (int i_set = 0; i_set < NUM_SETS; i_set = i_set + 1) begin
        for (int i_word = 0; i_word < WORDS_PER_LINE; i_word = i_word + 1) begin
            w_active[i_set][i_word] =
                (req_set == i_set) & // This set is selected
                (w_word_select == i_word) & // This word is selected
                ((hit & op_type == STORE) | load_mode); // A hit and a store OR just load_mode
        end
    end
end : write_active_logic

always_comb begin : write_bus_logic
    w_data = load_mode ? data_from_l2 : req_data_to_store;

    // B0
    unique casex (1'b1)
        (op_size == BYTE) & (w_byte_select == 2'b00): write_bus[0] = w_data[0];
        (op_size == HALF) & (w_byte_select == 2'b0?): write_bus[0] = w_data[0];
        (op_size == WORD) & (w_byte_select == 2'b??): write_bus[0] = w_data[0];
        default:                                      write_bus[0] = line_word[0];
    endcase

    // B1
    unique casex (1'b1)
        (op_size == BYTE) & (w_byte_select == 2'b01): write_bus[1] = w_data[0];
        (op_size == HALF) & (w_byte_select == 2'b0?): write_bus[1] = w_data[1];
        (op_size == WORD) & (w_byte_select == 2'b??): write_bus[1] = w_data[1];
        default:                                      write_bus[1] = line_word[1];
    endcase

    // B2
    unique casex (1'b1)
        (op_size == BYTE) & (w_byte_select == 2'b10): write_bus[2] = w_data[0];
        (op_size == HALF) & (w_byte_select == 2'b1?): write_bus[2] = w_data[0];
        (op_size == WORD) & (w_byte_select == 2'b??): write_bus[2] = w_data[2];
        default:                                      write_bus[2] = line_word[2];
    endcase

    // B3
    unique casex (1'b1)
        (op_size == BYTE) & (w_byte_select == 2'b11): write_bus[3] = w_data[0];
        (op_size == HALF) & (w_byte_select == 2'b1?): write_bus[3] = w_data[1];
        (op_size == WORD) & (w_byte_select == 2'b??): write_bus[3] = w_data[3];
        default:                                      write_bus[3] = line_word[3];
    endcase
end

always_ff @(posedge clk) begin
    for (int i_set = 0; i_set < NUM_SETS; i_set = i_set + 1) begin
        for (int i_word = 0; i_word < WORDS_PER_LINE; i_word = i_word + 1) begin
            for (int i_byte = 0; i_byte < BYTES_PER_WORD; i_byte = i_byte + 1) begin
                if (w_active[i_set][i_word]) begin
                    data_lines[i_set][i_word][i_byte] <= write_bus[i_byte];
                    dirty_array[i_set] <= 1'b1;
                end
            end
        end
    end
end

///////////////////////////////////////////////////////////////////
//                  Higher cache address logic                   //
///////////////////////////////////////////////////////////////////
logic [XLEN-OFS_SIZE-1:0] l2_block_address;

always_ff @(posedge clk) begin
    if (set_new_l2_block_address) begin
        l2_block_address <= {
            dirty_miss ? tag_array[req_set] : req_tag,
            req_set
        };
    end
end

assign l2_address = {l2_block_address, counter, {BYTE_SELECT_SIZE{1'b0}}};

endmodule
