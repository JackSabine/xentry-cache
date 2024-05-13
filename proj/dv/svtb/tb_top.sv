module tb_top;
    import uvm_pkg::*;
    import xentry_pkg::*;

    logic clk = 1'b0;
    logic reset = 1'b1;
    cache_if req_if(clk);
    higher_memory_if rsp_if(clk);

    icache dut (
        .clk(clk),
        .reset(reset),

        .pipe_req_address  (req_if.req_address),
        .pipe_req_type     (req_if.req_operation),
        .pipe_req_valid    (req_if.req_valid),
        .pipe_fetched_word (req_if.req_loaded_word),
        .pipe_req_fulfilled(req_if.req_fulfilled),

        .l2_req_address  (rsp_if.req_address),
        .l2_req_type     (rsp_if.req_operation),
        .l2_req_valid    (rsp_if.req_valid),
        .l2_fetched_word (rsp_if.req_loaded_word),
        .l2_req_fulfilled(rsp_if.req_fulfilled)
    );

    always #10 clk = !clk;
    initial begin
        repeat(10) @(posedge clk);
        reset = 1'b0;
    end

    initial begin
        uvm_config_db #(virtual cache_if)::set(
            .cntxt(null),
            .inst_name("uvm_test_top.*"),
            .field_name("memory_requester_if"),
            .value(req_if)
        );
        uvm_config_db #(virtual higher_memory_if)::set(
            .cntxt(null),
            .inst_name("uvm_test_top.*"),
            .field_name("memory_responder_if"),
            .value(rsp_if)
        );

        run_test();
    end
endmodule