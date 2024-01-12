`include "macros.svh"
// `define DEBUG_PRINT

class read_only_direct_mapped_cache_model;
    typedef struct packed {
        bit valid;
        uint32_t block_address;
    } cacheline_t;

    uint32_t num_sets;
    uint32_t set_bits;
    uint32_t offset_bits;

    cacheline_t sets[];

    function new(uint32_t cache_size, uint32_t cacheline_size, uint32_t offset_bits);
        this.num_sets = cache_size / cacheline_size;
        this.set_bits = $clog2(num_sets);
        this.offset_bits = offset_bits;

        this.sets = new [num_sets];

        foreach (sets[i]) begin
            this.sets[i].valid = 1'b0;
            this.sets[i].block_address = 0;
        end
    endfunction

    function uint32_t get_set_from_block_address(uint32_t block_address);
        uint32_t mask;

        mask = (1 << set_bits) - 1;
        return (block_address >> this.offset_bits) & mask;
    endfunction

    function bit is_cached(uint32_t block_address);
        uint32_t s;

        s = get_set_from_block_address(block_address);

        return (sets[s].valid) && (sets[s].block_address == block_address);
    endfunction

    function void install_block(uint32_t block_address);
        uint32_t s;

        s = get_set_from_block_address(block_address);

        sets[s].valid = 1'b1;
        sets[s].block_address = block_address;
    endfunction

    function void evict_block(uint32_t block_address);
        uint32_t s;

        s = get_set_from_block_address(block_address);

        if (is_cached(block_address)) begin
            sets[s].valid = 1'b0;
            sets[s].block_address = 0;
        end
    endfunction
endclass

module icache_full_test import xentry_pkg::*; ();

parameter LINE_SIZE = 16;    // 16 Bytes per block
parameter CACHE_SIZE = 256;  // Bytes
parameter XLEN = 32;         // bits
parameter NUM_LINES_TO_REFERENCE = 256;
parameter NUM_REQUESTS_PER_LINE = 256;
parameter NUM_MEMORY_BLOCKS_TO_POPULATE = NUM_LINES_TO_REFERENCE;
parameter TIMEOUT_NUM_CLOCKS = 1000000;
parameter CLKPER = 5;

localparam BYTES_PER_WORD = XLEN / 8;
localparam WORDS_PER_LINE = LINE_SIZE / BYTES_PER_WORD;
localparam OFS_SIZE = $clog2(LINE_SIZE);
localparam BYTE_SELECT_SIZE = $clog2(BYTES_PER_WORD);
localparam WORD_SELECT_SIZE = OFS_SIZE - BYTE_SELECT_SIZE;

localparam MAIN_MEMORY_DEFAULT_VALUE = 32'hACAB_0012;
localparam DCACHE_EXCHANGE_LATENCY = (LINE_SIZE / (XLEN / 8));
localparam DCACHE_MISS_LATENCY = 1 + DCACHE_EXCHANGE_LATENCY; // 1 for changing states

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
logic [XLEN-1:0] pipe_req_address = '0;
icache_memory_operation_e pipe_req_type;
logic pipe_req_valid = 1'b0;

//// SIGNALS TO PIPELINE (FROM DCACHE) ////
wire [XLEN-1:0] pipe_fetched_word;
wire pipe_req_fulfilled;

//// SIGNALS TO L2 (FROM DCACHE) ////
wire [XLEN-1:0] l2_req_address;
memory_operation_e l2_req_type;
wire l2_req_valid;

//// SIGNALS FROM L2 (TO DCACHE) ////
logic [XLEN-1:0] l2_fetched_word;
logic l2_req_fulfilled;

///////////////////////////////////
// Environment and golden output //
///////////////////////////////////
read_only_direct_mapped_cache_model metadata_model;

logic [XLEN-1:0] main_memory [uint32_t];
logic [XLEN-1:0] model_memory [uint32_t];
event tb_req_fulfilled;
bit disable_asserts = 1'b0;

bit expect_instant_req_fulfill = 1'b0;

// Load scoring
uint32_t expected_value;
uint32_t value_matches = 0;
uint32_t total_loads = 0;

// Store scoring
uint32_t total_stores = 0;

// Cacheline flush scoring
uint32_t total_clflushes = 0;

icache #(
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

                // main_memory[req_index] = l2_word_to_store;
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
    bit pass;

    pass = 1'b1;

    $display("################################################################");
    $display("#                        Test ending...                        #");
    $display("################################################################");

    if (test_if_memories_equal()) begin
        $display("Pass: Memories match!");
    end else begin
        $display("Fail: Memories differ");
        pass = 1'b0;
`ifdef DEBUG_PRINT
        print_memories();
`endif
    end

    if (value_matches != total_loads) begin
        $display("Fail: Load value match count discrepancy (%0d/%0d)", value_matches, total_loads);
        pass = 1'b0;
    end

    $display("### Totals ###");
    $display("Loads  : %0d", total_loads);
    $display("Stores : %0d", total_stores);
    $display("Flushes: %0d", total_clflushes);

    if (pass) begin
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

    mask = gen_bitmask(32);

    word_address = gen_word_address(block_address, word_offset, '0);

    return (model_memory[word_address] >> (8 * byte_offset)) & mask;
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

CACHED_BLOCK_AVAILABLE_IN_SAME_CYCLE: assert property (
    @(posedge clk) disable iff (!expect_instant_req_fulfill || disable_asserts)
    $rose(pipe_req_valid) |-> pipe_req_fulfilled
);

// TODO: model cache behavior to predict set conflicts and writebacks
// UNCACHED_BLOCK_AVAILABLE_IN_N_CYCLES: assert property (
//     @(posedge clk) disable iff (expect_instant_req_fulfill || disable_asserts)
//     $rose(pipe_req_valid) |-> ##(DCACHE_MISS_LATENCY) pipe_req_fulfilled
// );

initial begin
    uint32_t block_address;
    uint32_t block_address_set[$];
    uint32_t block_address_sequence[$];
    uint32_t word_address;
    bit [WORD_SELECT_SIZE-1:0] word_offset;
    bit [1:0] byte_offset;
    bit block_is_dirty;

    metadata_model = new(CACHE_SIZE, LINE_SIZE, OFS_SIZE);

    $display("Entering main test");

    assert(NUM_MEMORY_BLOCKS_TO_POPULATE >= 1) else $fatal(2, "PARAMETER ERROR: no memory blocks to populate");

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
            assert(std::randomize(word_offset, byte_offset, pipe_req_type) with {
                byte_offset == 2'b00;

                pipe_req_type dist {
                    ICACHE_LOAD := 9,
                    ICACHE_CLFLUSH := 1
                };
            });

            pipe_req_address = gen_word_address(block_address, word_offset, byte_offset);
            pipe_req_valid = 1'b1;

            case (pipe_req_type) inside
                ICACHE_LOAD: begin
                    expect_instant_req_fulfill = metadata_model.is_cached(block_address);
                end

                ICACHE_CLFLUSH: begin
                    expect_instant_req_fulfill = 1'b1;
                end
            endcase

            @(tb_req_fulfilled);

            case (pipe_req_type)
                ICACHE_LOAD: begin
                    if (!metadata_model.is_cached(block_address)) metadata_model.install_block(block_address);

                    expected_value = generate_expected_value(block_address, word_offset, byte_offset);

                    if (pipe_fetched_word == expected_value) begin
                        value_matches++;
                    end else begin
                        $error("Loaded data mismatch");
                    end

                    total_loads++;
                end

                ICACHE_CLFLUSH: begin
                    metadata_model.evict_block(block_address);

                    total_clflushes++;
                end
            endcase
            pipe_req_valid = 1'b0;

            @(posedge clk);
        end
    end

    // Force flush every line
    disable_asserts = 1'b1;
    foreach(block_address_sequence[i]) begin
        block_address = block_address_sequence[i];

        pipe_req_address = gen_word_address(block_address, '0, '0);

        pipe_req_type = ICACHE_CLFLUSH;
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
