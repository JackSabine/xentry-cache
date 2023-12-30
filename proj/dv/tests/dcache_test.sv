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

//// SIGNALS FROM PIPELINE ////
logic [XLEN-1:0] pipe_req_address;
memory_operation_size_e pipe_req_size = WORD;
memory_operation_e pipe_req_type = LOAD;
logic pipe_req_valid = 1'b0;

//// SIGNALS TO PIPELINE ////
wire [XLEN-1:0] pipe_word;
wire pipe_word_valid;

//// SIGNALS TO L2 ////
wire [XLEN-1:0] l2_address;
wire l2_access;

//// SIGNALS FROM L2 ////
wire [XLEN-1:0] l2_word;
wire l2_word_valid;

///////////////////////////////////
// Environment and golden output //
///////////////////////////////////

int i;

logic [XLEN-1:0] addresses_to_load [0:1] = {
    32'hBEEF67_B_A,
    32'h000188_C_F
};

logic [XLEN-1:0] faux_memory [0:7] = {
    32'h01234567,
    32'h89ABCDEF,
    32'h00112233,
    32'h44556677,
    32'h8899AABB,
    32'hCCDDEEFF,
    32'hFEDCBA98,
    32'h76543210
};

logic [XLEN-1:0] golden_loaded_value;

assign golden_loaded_value = faux_memory[addresses_to_load[i][3:2]];

logic [XLEN-1:0] loaded_value;

assign match = (loaded_value == golden_loaded_value);

dcache #(
    .LINE_SIZE(LINE_SIZE),
    .CACHE_SIZE(CACHE_SIZE),
    .XLEN(XLEN)
) dut (.*);

assign l2_word = l2_access ? faux_memory[l2_address[3:2]] : 32'hx;
assign l2_word_valid = l2_access;

always_ff @(posedge clk) begin
    if (reset) begin
        loaded_value <= 'b0;
    end else if (pipe_word_valid) begin
        loaded_value <= pipe_word;
    end
end

initial begin
    repeat(5) @(posedge clk);
    reset = 0;
    repeat(5) @(posedge clk);

    for (i = 0; i < $size(addresses_to_load); i = i + 1) begin
        pipe_req_address = addresses_to_load[i];
        pipe_req_valid = 1'b1;
        @(posedge pipe_word_valid);
        @(posedge clk);
        pipe_req_valid = 1'b0;
        repeat(5) @(posedge clk);
    end

    $finish(1);
end

initial begin
    @(posedge timeout);
    $error("Test timed out");
end

endmodule