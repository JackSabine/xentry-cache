// `define DEBUG_PRINT

module dcache_store_test import xentry_pkg::*; ();

parameter LINE_SIZE = 16;    // 16 Bytes per block
parameter CACHE_SIZE = 256;  // Bytes
parameter XLEN = 32;         // bits
parameter NUM_LINES_TO_REFERENCE = 2048;
parameter NUM_REQUESTS_PER_LINE = 8;
parameter NUM_MEMORY_BLOCKS_TO_POPULATE = NUM_LINES_TO_REFERENCE;
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
memory_operation_e pipe_req_type = STORE;
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
logic l2_req_fulfilled;

///////////////////////////////////
// Environment and golden output //
///////////////////////////////////
typedef int unsigned uint32_t;

logic [XLEN-1:0] main_memory [uint32_t];
logic [XLEN-1:0] model_memory [uint32_t];
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
`ifdef DEBUG_PRINT
                $display("Storing 0x%08x at address 0x%08x", l2_word_to_store, req_index);
`endif
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
`ifdef DEBUG_PRINT
                $display("Loading 0x%08x from address 0x%08x", l2_fetched_word, req_index);
`endif
            end
        end
    end
end

function void print_test_summary();
    $display("################################################################");
    $display("#                        Test ending...                        #");
    $display("################################################################");

`ifdef DEBUG_PRINT
    print_memories();
`endif

    if (test_if_memories_equal()) begin
        $display("PASS");
    end else begin
        $display("FAIL");
    end
endfunction

function void print_memories();
    uint32_t word_addresses[$];
    uint32_t model_memory_word_addresses[$];
    uint32_t main_memory_word_addresses[$];
    string model_data, main_data;
    string diff_flag;

    model_memory_word_addresses = model_memory.find_index() with ('1);
    main_memory_word_addresses = main_memory.find_index() with ('1);

    word_addresses = model_memory_word_addresses;

    foreach (main_memory_word_addresses[i]) begin
        if (!model_memory.exists(main_memory_word_addresses[i])) begin
            word_addresses.push_back(main_memory_word_addresses[i]);
        end
    end

    word_addresses.sort();

    $display("address  | model    | main    ");
    $display("---------+----------+---------");

    foreach (word_addresses[i]) begin
        model_data = model_memory.exists(word_addresses[i]) ? $sformatf("%08x", model_memory[word_addresses[i]]) : "";
        main_data =  main_memory.exists(word_addresses[i])  ? $sformatf("%08x", main_memory[word_addresses[i]])  : "";

        diff_flag = model_data != main_data ? "!" : "";

        $display("%08x | %8s | %8s %0s", word_addresses[i], model_data, main_data, diff_flag);
    end
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

    return (main_memory[word_address] >> (8 * byte_offset)) & mask;
endfunction

function void update_model_memory(uint32_t pipe_word_to_store, uint32_t block_address, bit[WORD_SELECT_SIZE-1:0] word_offset, bit[BYTE_SELECT_SIZE-1:0] byte_offset, memory_operation_size_e pipe_req_size);
    uint32_t word_address;
    uint32_t mask;
    uint32_t temp;

    unique case (pipe_req_size)
        BYTE: mask = gen_bitmask(8);
        HALF: mask = gen_bitmask(16);
        WORD: mask = gen_bitmask(32);
    endcase

    word_address = gen_word_address(block_address, word_offset, '0);

`ifdef DEBUG_PRINT
    $display("Performing a %0s store to word address 0x%08x (byte %02b) with value 0x%08x", pipe_req_size.name, word_address, byte_offset, pipe_word_to_store);
`endif

    temp = model_memory[word_address];
    temp = temp & ~(mask << (8 * byte_offset));
    temp = temp | (pipe_word_to_store << (8 * byte_offset));

    model_memory[word_address] = temp;
endfunction

function bit test_if_memories_equal();
    bit fail;
    int matching_valid_entries;

    // model_memory assumed to be the "good" memory
    // main_memory is what the DUT modified

    fail = 0;
    matching_valid_entries = 0;

    if (model_memory.size != main_memory.size) begin
        $display("Memory structures differ in size");
        fail = 1;
    end

    foreach (model_memory[i]) begin
        if (main_memory.exists(i)) begin
            if (main_memory[i] == model_memory[i]) begin
                matching_valid_entries++;
            end else begin
                $display(
                    "data in model_memory doesn't match main_memory at address 0x%08x - model_memory(0x%08x) main_memory(0x%08x)",
                    i,
                    model_memory[i],
                    main_memory[i]
                );
                fail = 1;
            end
        end else begin
            $display("main_memory doesn't contain data at address 0x%08x", i);
            fail = 1;
        end
    end

    return !fail;
endfunction

always @(posedge clk) if (pipe_req_fulfilled) ->tb_req_fulfilled;

initial begin
    uint32_t block_address;
    uint32_t block_address_set[$];
    uint32_t block_address_sequence[$];
    uint32_t word_address;
    bit [WORD_SELECT_SIZE-1:0] word_offset;
    bit [1:0] byte_offset;

    $display("Entering main test");

    assert(NUM_MEMORY_BLOCKS_TO_POPULATE >= NUM_LINES_TO_REFERENCE) else $fatal(2, "PARAMETER ERROR: more lines to reference than memory blocks");

    repeat(NUM_MEMORY_BLOCKS_TO_POPULATE) begin
        block_address = uint32_t'($urandom() & ~gen_bitmask(OFS_SIZE));
        for (uint32_t i = 0; i < WORDS_PER_LINE; i++) begin
            word_address = gen_word_address(block_address, i, '0);
            main_memory[word_address] = $urandom();
        end
        block_address_set.push_back(block_address);
    end

    model_memory = main_memory;

    $display("Finished generating main_memory");

    repeat(NUM_LINES_TO_REFERENCE) begin
        assert(std::randomize(block_address) with {
            foreach(block_address_sequence[i]) {
                block_address != block_address_sequence[i];
            }
            block_address inside {block_address_set};
        });
        block_address_sequence.push_back(block_address);
    end

    $display("Finished generating block_address_sequence (len %0d)", block_address_sequence.size());

    repeat(5) @(posedge clk);
    reset = 0;
    repeat(5) @(posedge clk);

    foreach(block_address_sequence[i]) begin
        block_address = block_address_sequence[i];

        for (uint32_t j = 0; j < NUM_REQUESTS_PER_LINE; j++) begin
            assert(std::randomize(pipe_req_size, word_offset, byte_offset, pipe_word_to_store) with {
                if (pipe_req_size == WORD) {
                    byte_offset inside {2'b00};
                } else if (pipe_req_size == HALF) {
                    byte_offset inside {2'b00, 2'b10};
                    pipe_word_to_store <= {16{1'b1}};
                } else if (pipe_req_size == BYTE) {
                    pipe_word_to_store <= {8{1'b1}};
                }
                solve pipe_req_size before byte_offset;
            });

            update_model_memory(pipe_word_to_store, block_address, word_offset, byte_offset, pipe_req_size);

            pipe_req_address = gen_word_address(block_address, word_offset, byte_offset);

            pipe_req_valid = 1'b1;
            @(tb_req_fulfilled);
            pipe_req_valid = 1'b0;

            @(posedge clk);
        end
    end

    // Force flush every line
    foreach(block_address_sequence[i]) begin
        block_address = block_address_sequence[i];

        pipe_req_address = gen_word_address(block_address, '0, '0);

        pipe_req_type = CLFLUSH;
        pipe_req_valid = 1'b1;
        @(tb_req_fulfilled);
        pipe_req_valid = 1'b0;

        @(posedge clk);
    end

    print_test_summary();
    $finish(1);
end

initial begin
    @(posedge timeout);
    $display("#####################################");
    $display("timeout signal observed, killing test");
    print_memories();

    print_test_summary();
    $fatal(2, "Test timed out");
end

endmodule
