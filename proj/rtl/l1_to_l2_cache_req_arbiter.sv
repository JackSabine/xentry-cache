module l1_to_l2_cache_req_arbiter import xentry_types::*; #(
    parameter XLEN = 32
) (
    input wire clk,
    input wire reset,

    //// ICACHE Interface ////
    input wire [XLEN-1:0] icache_req_address,
    input wire icache_req_valid,
    output wire [XLEN-1:0] icache_fetched_word,
    output wire icache_req_fulfilled,

    //// DCACHE Interface ////
    input wire [XLEN-1:0] dcache_req_address,
    input wire memory_operation_e dcache_req_type,
    input wire dcache_req_valid,
    input wire [XLEN-1:0] dcache_word_to_store,
    output wire [XLEN-1:0] dcache_fetched_word,
    output wire dcache_req_fulfilled,

    //// L2 Interface ////
    output wire [XLEN-1:0] req_address,
    output wire memory_operation_e req_type,
    output wire req_valid,
    output wire [XLEN-1:0] word_to_store,
    input wire [XLEN-1:0] fetched_word,
    input wire req_fulfilled
);

typedef enum logic[1:0] {
    ST_IDLE = 2'b00,
    ST_SERVING_ICACHE = 2'b10,
    ST_SERVING_DCACHE = 2'b11,
    ST_UNKNOWN = 2'bxx
} arbiter_state_e;

arbiter_state_e state, next_state;

logic serve_icache;

always_comb begin
    serve_icache = 1'b0;

    case (state)
        ST_IDLE: begin
            if (icache_req_valid) begin
                next_state = ST_SERVING_ICACHE;
                serve_icache = 1'b1;
            end else if (dcache_req_valid) begin
                next_state = ST_SERVING_DCACHE;
            end
        end

        ST_SERVING_ICACHE: begin
            serve_icache = 1'b1;
            next_state = icache_req_fulfilled ? ST_IDLE : ST_SERVING_ICACHE;
        end

        ST_SERVING_DCACHE: begin
            next_state = dcache_req_fulfilled ? ST_IDLE : ST_SERVING_DCACHE;
        end

        default: begin
            next_state = ST_IDLE;
        end
    endcase
end

assign icache_fetched_word  = serve_icache ? fetched_word  : '0;
assign icache_req_fulfilled = serve_icache ? req_fulfilled : 1'b0;

assign dcache_fetched_word  = serve_icache ? '0   : fetched_word;
assign dcache_req_fulfilled = serve_icache ? 1'b0 : req_fulfilled;

assign req_address   = serve_icache ? icache_req_address : dcache_req_address;
assign req_type      = serve_icache ? LOAD               : dcache_req_type;
assign req_valid     = serve_icache ? icache_req_valid   : dcache_req_valid;
assign word_to_store = serve_icache ? '0                 : dcache_word_to_store;

//// STATE REGISTER ////
always_ff @(posedge clk) begin
    if (reset) begin
        state <= ST_IDLE;
    end else begin
        state <= next_state;
    end
end

endmodule