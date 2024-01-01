module dcache_test import xentry_pkg::*; ();

parameter LINE_SIZE = 16;    // 16 Bytes per block
parameter CACHE_SIZE = 256;  // Bytes
parameter XLEN = 32;         // bits

/////////////////////////
// Testbench utilities //
/////////////////////////
logic clk = 0;
logic reset = 1;

always #5 clk = ~clk;

int timer = 0;
wire timeout;

always @(posedge clk) timer = timer + 1;

assign timeout = (timer >= 500);

/////////////////////////
// Signals             //
/////////////////////////

//// SIGNALS FROM PIPELINE (TO DCACHE) ////
logic [XLEN-1:0] pipe_req_address;
memory_operation_size_e pipe_req_size = WORD;
memory_operation_e pipe_req_type = LOAD;
logic pipe_req_valid = 1'b0;
logic [XLEN-1:0] pipe_word_to_store;

//// SIGNALS TO PIPELINE (FROM DCACHE) ////
wire [XLEN-1:0] pipe_fetched_word;
wire pipe_fetched_word_valid;

//// SIGNALS TO L2 (FROM DCACHE) ////
wire [XLEN-1:0] l2_req_address;
memory_operation_e l2_req_type;
wire l2_req_valid;
wire [XLEN-1:0] l2_word_to_store;

//// SIGNALS FROM L2 (TO DCACHE) ////
logic [XLEN-1:0] l2_fetched_word;
logic l2_fetched_word_valid;

///////////////////////////////////
// Environment and golden output //
///////////////////////////////////

bit [XLEN-1:0] value;

logic [XLEN-1:0] golden_memory_structure [int];
logic [XLEN-1:0] recreated_memory_structure [int];

dcache #(
    .LINE_SIZE(LINE_SIZE),
    .CACHE_SIZE(CACHE_SIZE),
    .XLEN(XLEN)
) dut (.*);

always @(l2_req_address, l2_req_valid, l2_req_type) begin
    if (golden_memory_structure.exists(l2_req_address)) begin
        l2_fetched_word = golden_memory_structure[l2_req_address];
    end else begin
        l2_fetched_word = 32'hx;
    end
    l2_fetched_word_valid = (l2_req_valid & l2_req_type == LOAD);
end



initial forever begin
    @(posedge clk);
    if (pipe_fetched_word_valid) begin
        recreated_memory_structure[pipe_req_address] = pipe_fetched_word;
    end
end

function void print_memories();
    $display("### Full memory printout ###");
    $display("# Golden #");
    foreach (golden_memory_structure[i]) $display("%08x: %08x", i, golden_memory_structure[i]);
    $display("# Recreated #");
    foreach (recreated_memory_structure[i]) $display("%08x: %08x", i, recreated_memory_structure[i]);
endfunction

function bit test_if_memories_equal();
    bit fail;
    int matching_valid_entries;

    fail = 0;
    matching_valid_entries = 0;

    if (golden_memory_structure.size != recreated_memory_structure.size) begin
        $display("Memory structures differ in size");
        fail = 1;
    end

    foreach (golden_memory_structure[i]) begin
        if (recreated_memory_structure.exists(i)) begin
            if (recreated_memory_structure[i] == golden_memory_structure[i]) begin
                matching_valid_entries++;
            end else begin
                $error(
                    "data in recreated memory doesn't match golden memory at address 0x%08x - recreated(0x%08x) golden(0x%08x)",
                    i, recreated_memory_structure[i],
                    golden_memory_structure[i]
                );
                fail = 1;
            end
        end else begin
            $error("recreated memory doesn't contain data at address 0x%08x", i);
            fail = 1;
        end
    end

    if (fail) begin
        print_memories();
    end

    return !fail;
endfunction

initial begin
    golden_memory_structure[32'hBEEF67_B_A] = std::randomize(value);
    golden_memory_structure[32'h000188_C_F] = std::randomize(value);
    golden_memory_structure[32'h000188_0_F] = std::randomize(value);

    repeat(5) @(posedge clk);
    reset = 0;
    repeat(5) @(posedge clk);

    foreach(golden_memory_structure[i]) begin
        pipe_req_address = i;
        pipe_req_valid = 1'b1;
        @(posedge pipe_fetched_word_valid);
        @(posedge clk);
        pipe_req_valid = 1'b0;
        repeat(5) @(posedge clk);
    end

    if (test_if_memories_equal() == 1'b1) $display("Pass");
    else $display("Fail");

    $finish(1);
end

initial begin
    @(posedge timeout);
    $error("Test timed out");
end

endmodule