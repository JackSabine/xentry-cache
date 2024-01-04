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
uint32_t expected_value;
wire match;
event tb_req_fulfilled;

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

            l2_fetched_word = main_memory.exists(req_index) ?
                main_memory[req_index] :
                32'hABAC_0012;
        end
    end
end

function uint32_t generate_expected_value(uint32_t index, bit[1:0] byte_offset);
    uint32_t mask;
    unique case (pipe_req_size)
        BYTE: mask = 32'h0000_00FF;
        HALF: mask = 32'h0000_FFFF;
        WORD: mask = 32'hFFFF_FFFF;
    endcase
    return (main_memory[index] >> (8 * byte_offset)) & mask;
endfunction

assign match = pipe_req_fulfilled & (pipe_fetched_word == expected_value);

always @(posedge clk) if (pipe_req_fulfilled) ->tb_req_fulfilled;

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

        expected_value = generate_expected_value(index, byte_offset);

        pipe_req_address = index | byte_offset;
        pipe_req_valid = 1'b1;

        @(tb_req_fulfilled);
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