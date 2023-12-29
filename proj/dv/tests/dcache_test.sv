module dcache_test();

parameter LINE_SIZE = 32;    // 32 Bytes per block
parameter CACHE_SIZE = 1024; // Bytes
parameter XLEN = 32;         // bits

localparam NUM_SETS = CACHE_SIZE / (LINE_SIZE);

localparam OFS_SIZE = $clog2(LINE_SIZE),
           SET_SIZE = $clog2(NUM_SETS),
           TAG_SIZE = XLEN - (SET_SIZE + OFS_SIZE);

localparam OFS_POS = 0,
           SET_POS = OFS_POS + OFS_SIZE,
           TAG_POS = SET_POS + SET_SIZE;

wire [OFS_SIZE-1:0] req_ofs;
wire [SET_SIZE-1:0] req_set;
wire [TAG_SIZE-1:0] req_tag;

logic [XLEN-1:0] address;

assign req_ofs = address[OFS_POS +: OFS_SIZE];
assign req_set = address[SET_POS +: SET_SIZE];
assign req_tag = address[TAG_POS +: TAG_SIZE];

logic clk = 0;
logic reset = 1;

always #5 clk = ~clk;

dcache_datapath #(
    .LINE_SIZE(LINE_SIZE),
    .OFS_SIZE(OFS_SIZE),
    .SET_SIZE(SET_SIZE),
    .TAG_SIZE(TAG_SIZE),
    .NUM_SETS(NUM_SETS),
    .XLEN(XLEN)
) dut (
    .clk(clk),
    .reset(reset)
);

initial begin
    #20;
    reset = 0;

    #20;
    $finish(1);
end

endmodule