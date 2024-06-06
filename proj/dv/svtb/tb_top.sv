module tb_top;
    import uvm_pkg::*;
    import torrence_pkg::*;

    parameter LINE_SIZE = 32;
    parameter CACHE_SIZE = 1024;
    parameter XLEN = 32;

    cache_config dut_config;
    clock_config clk_config;

    bit clk_enabled = 1'b0;
    logic clk = 1'b0;
    cache_if req_if(clk);
    higher_memory_if rsp_if(clk);
    reset_if rst_if(clk);

    icache #(
        .LINE_SIZE(LINE_SIZE),
        .CACHE_SIZE(CACHE_SIZE),
        .XLEN(XLEN)
    ) dut (
        .clk(clk),
        .reset(rst_if.reset),

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

    initial begin
        @(posedge clk_enabled);

        forever begin
            clk = 1'b1;
            #(clk_config.t_high);
            clk = 1'b0;
            #(clk_config.t_low);
        end
    end

    initial begin
        dut_config = cache_config::type_id::create("dut_config");
        dut_config.set(LINE_SIZE, CACHE_SIZE, 1);
        dut_config.print();

        clk_config = clock_config::type_id::create("clk_config");
        assert(clk_config.randomize()) else `uvm_fatal("tb_top", "Could not randomize clk_config")
        `uvm_info("tb_top", clk_config.sprint(), UVM_LOW)
        clk_enabled = 1'b1;

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
        uvm_config_db #(virtual reset_if)::set(
            .cntxt(null),
            .inst_name("uvm_test_top.*"),
            .field_name("reset_if"),
            .value(rst_if)
        );
        uvm_config_db #(cache_config)::set(
            .cntxt(null),
            .inst_name("*"),
            .field_name("cache_config"),
            .value(dut_config)
        );
        uvm_config_db #(clock_config)::set(
            .cntxt(null),
            .inst_name("*"),
            .field_name("clock_config"),
            .value(clk_config)
        );
        run_test();
    end
endmodule