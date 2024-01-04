// `define DEBUG_PRINT

module dcache_load_test import xentry_pkg::*; ();

parameter LINE_SIZE = 16;    // 16 Bytes per block
parameter CACHE_SIZE = 256;  // Bytes
parameter XLEN = 32;         // bits
parameter NUM_LOADS = 2048;
parameter NUM_MEMORY_ENTRIES = 2048;
parameter TIMEOUT_NUM_CLOCKS = 100000;
parameter CLKPER = 5;

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
memory_operation_e pipe_req_type = LOAD;
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
uint32_t passes = 0;
uint32_t fails = 0;

dcache #(
    .LINE_SIZE(LINE_SIZE),
    .CACHE_SIZE(CACHE_SIZE),
    .XLEN(XLEN)
) dut (.*);

initial begin
    uint32_t req_index;

    forever begin
        @(l2_req_address or l2_req_valid or l2_req_type);
        l2_req_fulfilled = (l2_req_valid & l2_req_type == LOAD);

        if (!$isunknown(l2_req_address) && l2_req_fulfilled) begin
            req_index = uint32_t'(l2_req_address);

            if (main_memory.exists(req_index)) begin
                l2_fetched_word = main_memory[req_index];
            end else begin
                l2_fetched_word = 32'hABAC_0012;
            end
`ifdef DEBUG_PRINT
            $display("Performing lookup for req_index %0d/0x%08x, got %08x", req_index, req_index, l2_fetched_word);
`endif
        end
    end
end

uint32_t expected_value;
wire match;

assign match = pipe_req_fulfilled & (pipe_fetched_word == expected_value);

initial begin
    uint32_t index;
    uint32_t index_list[$];
    bit [1:0] byte_offset;

    repeat(NUM_MEMORY_ENTRIES) begin
        index = uint32_t'($urandom() & ~32'h7);
        main_memory[index] = $urandom();
    end

    index_list = main_memory.find_index() with ('1);

    $display("Finished generating main memory");

    repeat(5) @(posedge clk);
    reset = 0;
    repeat(5) @(posedge clk);

    repeat(NUM_LOADS) begin
        @(posedge clk);
        assert(std::randomize(index) with {
            index inside {index_list};
        });
        assert(std::randomize(pipe_req_size));
        assert(std::randomize(byte_offset) with {
            if (pipe_req_size == WORD) {
                byte_offset inside {2'b00};
            } else if (pipe_req_size == HALF) {
                byte_offset inside {2'b00, 2'b10};
            }
        });
`ifdef DEBUG_PRINT
        $display("%0s - %02b", pipe_req_size.name, byte_offset);
`endif

        expected_value = main_memory[index] >> (8 * byte_offset);
        case (pipe_req_size)
        BYTE: expected_value = expected_value & 32'h0000_00FF;
        HALF: expected_value = expected_value & 32'h0000_FFFF;
        WORD: expected_value = expected_value & 32'hFFFF_FFFF;
        endcase

        pipe_req_address = index | byte_offset;
        pipe_req_valid = 1'b1;

        @(posedge pipe_req_fulfilled);
        assert(!$isunknown(|pipe_fetched_word));

        @(posedge clk);
        pipe_req_valid = 1'b0;

        if (match) begin
            passes++;
        end else begin
            fails++;
        end
    end

    $display("Passes: %0d, Fails: %0d", passes, fails);
    if (fails != 0) $error("FAIL");

    $finish(1);
end

initial begin
    @(posedge timeout);
    $display("#####################################");
    $display("timeout signal observed, killing test");
    // print_memories();

    $display("Passes: %0d, Fails: %0d", passes, fails);
    $fatal(2, "Test timed out");
end

endmodule