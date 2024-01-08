`include "macros.svh"
// `define DEBUG_PRINT

module dcache_clflush_test import xentry_pkg::*; ();

parameter LINE_SIZE = 16;    // 16 Bytes per block
parameter CACHE_SIZE = 256;  // Bytes
parameter XLEN = 32;         // bits
parameter NUM_LINES_TO_LOAD = 8;
parameter NUM_REQUESTS_PER_LINE = 4;
parameter NUM_MEMORY_ENTRIES = 2048;
parameter TIMEOUT_NUM_CLOCKS = 100000;
parameter CLKPER = 5;

localparam BYTES_PER_WORD = XLEN / 8;
localparam WORDS_PER_LINE = LINE_SIZE / BYTES_PER_WORD;
localparam OFS_SIZE = $clog2(LINE_SIZE);
localparam BYTE_SELECT_SIZE = $clog2(BYTES_PER_WORD);
localparam WORD_SELECT_SIZE = OFS_SIZE - BYTE_SELECT_SIZE;

localparam MAIN_MEMORY_DEFAULT_VALUE = 32'hACAB_0012;

/////////////////////////
// Testbench utilities //
/////////////////////////
logic clk = 0;
logic reset = 1;

always #CLKPER clk = ~clk;

int timer = 0;
wire timeout;

always @(posedge clk) timer <= timer + 1;

assign timeout = (timer >= TIMEOUT_NUM_CLOCKS);

/////////////////////////
// Signals             //
/////////////////////////

//// SIGNALS FROM PIPELINE (TO DCACHE) ////
logic [XLEN-1:0] pipe_req_address;
memory_operation_size_e pipe_req_size;
memory_operation_e pipe_req_type;
logic pipe_req_valid = 1'b0;
logic [XLEN-1:0] pipe_word_to_store;

//// SIGNALS TO PIPELINE (FROM DCACHE) ////
wire [XLEN-1:0] pipe_fetched_word;
wire pipe_req_fulfilled;

//// SIGNALS TO L2 (FROM DCACHE) ////
wire [XLEN-1:0] l2_req_address;
memory_operation_e l2_req_type;
wire l2_req_valid;
wire [XLEN-1:0] l2_word_to_store;

//// SIGNALS FROM L2 (TO DCACHE) ////
logic [XLEN-1:0] l2_fetched_word;
wire l2_req_fulfilled;

///////////////////////////////////
// Environment and golden output //
///////////////////////////////////
logic [XLEN-1:0] main_memory [uint32_t];
uint32_t expected_value;
wire match;
event tb_req_fulfilled;

dcache #(
    .LINE_SIZE(LINE_SIZE),
    .CACHE_SIZE(CACHE_SIZE),
    .XLEN(XLEN)
) dut (.*);

assign l2_req_fulfilled = l2_req_valid;

function uint32_t main_memory_lookup(uint32_t word_address);
    return main_memory.exists(word_address) ?
        main_memory[word_address] :
        MAIN_MEMORY_DEFAULT_VALUE;
endfunction

// main_memory store logic
initial begin
    uint32_t req_index;

    forever begin
        @(posedge clk);

        if (l2_req_fulfilled && l2_req_type == STORE) begin
            if (!$isunknown(l2_req_address)) begin
                req_index = uint32_t'(l2_req_address);

                main_memory[req_index] = l2_word_to_store;
            end
        end
    end
end

// main_memory load logic
initial begin
    uint32_t req_index;

    forever begin
        @(l2_req_fulfilled or l2_req_type or l2_req_address)

        if (l2_req_fulfilled && l2_req_type == LOAD) begin
            if (!$isunknown(l2_req_address)) begin
                req_index = uint32_t'(l2_req_address);

                l2_fetched_word = main_memory_lookup(req_index);
            end
        end
    end
end

function void print_test_summary();

endfunction

function uint32_t gen_bitmask(uint32_t num_bits);
    return (1 << num_bits) - 32'd1;
endfunction

function uint32_t gen_full_offset(bit[WORD_SELECT_SIZE-1:0] word_offset, bit[BYTE_SELECT_SIZE-1:0] byte_offset);
    return {word_offset, byte_offset};
endfunction

function uint32_t gen_word_offset(bit[WORD_SELECT_SIZE-1:0] word_offset);
    return gen_full_offset(word_offset, '0);
endfunction

function uint32_t gen_word_address(uint32_t block_address, bit[WORD_SELECT_SIZE-1:0] word_offset, bit[BYTE_SELECT_SIZE-1:0] byte_offset);
    return block_address | gen_full_offset(word_offset, byte_offset);
endfunction

function uint32_t generate_expected_value(uint32_t block_address, bit[WORD_SELECT_SIZE-1:0] word_offset, bit[1:0] byte_offset);
    uint32_t mask;
    uint32_t word_address;

    unique case (pipe_req_size)
        BYTE: mask = gen_bitmask(8);
        HALF: mask = gen_bitmask(16);
        WORD: mask = gen_bitmask(32);
    endcase

    word_address = gen_word_address(block_address, word_offset, '0);

    return (main_memory_lookup(word_address) >> (8 * byte_offset)) & mask;
endfunction

assign match = pipe_req_fulfilled & (pipe_req_type == LOAD) & (pipe_fetched_word == expected_value);

always @(posedge clk) if (pipe_req_fulfilled) ->tb_req_fulfilled;

initial begin
    uint32_t block_address;
    uint32_t block_address_sequence[$];
    uint32_t word_address;
    bit [WORD_SELECT_SIZE-1:0] word_offset;
    bit [1:0] byte_offset;

    $display("Entering main test");

    repeat(1) begin
        assert(std::randomize(block_address) with {
            foreach(block_address_sequence[i]) {
                block_address != block_address_sequence[i];
            }
        });
        block_address_sequence.push_back(block_address);
    end

    $display("Finished generating block_address_sequence");

    repeat(5) @(posedge clk);
    reset = 0;
    repeat(5) @(posedge clk);

    foreach(block_address_sequence[i]) begin
        block_address = block_address_sequence[i];

        assert(std::randomize(pipe_req_size, word_offset, byte_offset) with {
            if (pipe_req_size == WORD) {
                byte_offset inside {2'b00};
            } else if (pipe_req_size == HALF) {
                byte_offset inside {2'b00, 2'b10};
            }
            solve pipe_req_size before byte_offset;

            pipe_req_size == WORD;
        });

        expected_value = generate_expected_value(block_address, word_offset, byte_offset);
        pipe_req_address = gen_word_address(block_address, word_offset, byte_offset);

        // Block not present
        @(posedge clk);
        pipe_req_type = CLFLUSH;
        pipe_req_valid = 1'b1;

        @(tb_req_fulfilled);
        pipe_req_valid = 1'b0;

        // Load block
        @(posedge clk);
        pipe_req_type = LOAD;
        pipe_req_valid = 1'b1;

        @(tb_req_fulfilled);
        pipe_req_valid = 1'b0;

        // Flush a present clean block
        @(posedge clk);
        pipe_req_type = CLFLUSH;
        pipe_req_valid = 1'b1;

        @(tb_req_fulfilled);
        pipe_req_valid = 1'b0;

        // Load block
        @(posedge clk);
        pipe_req_type = LOAD;
        pipe_req_valid = 1'b1;

        @(tb_req_fulfilled);
        pipe_req_valid = 1'b0;

        // Write to block
        @(posedge clk);
        pipe_req_type = STORE;
        pipe_word_to_store = 32'hFEED_BEEF;
        pipe_req_valid = 1'b1;

        @(tb_req_fulfilled);
        pipe_req_valid = 1'b0;

        // Flush a present dirty block
        @(posedge clk);
        pipe_req_type = CLFLUSH;
        pipe_req_valid = 1'b1;

        @(tb_req_fulfilled);
        pipe_req_valid = 1'b0;

        // Load block
        @(posedge clk);
        pipe_req_type = LOAD;
        pipe_req_valid = 1'b1;

        @(tb_req_fulfilled);
        pipe_req_valid = 1'b0;
    end

    @(posedge clk);

    print_test_summary();
    $finish(1);
end

initial begin
    @(posedge timeout);
    $display("#####################################");
    $display("timeout signal observed, killing test");
    // print_memories();

    print_test_summary();
    $fatal(2, "Test timed out");
end

endmodule
