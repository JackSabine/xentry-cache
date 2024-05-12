module tb_top;
    import uvm_pkg::*;
    import xentry_pkg::*;

    logic clk = 1'b0;
    logic reset = 1'b1;
    memory_if req_if(clk);
    icache dut (
        .clk(clk),
        .reset(reset),

        .pipe_req_address  (req_if.address),
        .pipe_req_type     (req_if.op),
        .pipe_req_valid    (req_if.req_valid),
        .pipe_fetched_word (req_if.fetched_word),
        .pipe_req_fulfilled(req_if.req_fulfilled),

        .l2_req_address  (),
        .l2_req_type     (),
        .l2_req_valid    (),
        .l2_fetched_word (),
        .l2_req_fulfilled()
    );

    always #10 clk = !clk;
    initial begin
        repeat(10) @(posedge clk);
        reset = 1'b0;
    end

    initial begin
        uvm_config_db #(virtual memory_if)::set(
            .cntxt(null),
            .inst_name(""),
            .field_name("memory_requester_if"),
            .value(req_if)
        );
        run_test();
    end
endmodule