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
    cache_if         icache_req_if(clk);
    higher_memory_if icache_rsp_if(clk);
    cache_if         dcache_req_if(clk);
    higher_memory_if dcache_rsp_if(clk);
    reset_if rst_if(clk);

    icache #(
        .LINE_SIZE(LINE_SIZE),
        .CACHE_SIZE(CACHE_SIZE),
        .XLEN(XLEN)
    ) icache_dut (
        .clk(clk),
        .reset(rst_if.reset),

        .pipe_req_address  (icache_req_if.req_address),
        .pipe_req_type     (icache_req_if.req_operation),
        .pipe_req_valid    (icache_req_if.req_valid),
        .pipe_fetched_word (icache_req_if.req_loaded_word),
        .pipe_req_fulfilled(icache_req_if.req_fulfilled),

        .l2_req_address  (icache_rsp_if.req_address),
        .l2_req_type     (icache_rsp_if.req_operation),
        .l2_req_valid    (icache_rsp_if.req_valid),
        .l2_fetched_word (icache_rsp_if.req_loaded_word),
        .l2_req_fulfilled(icache_rsp_if.req_fulfilled)
    );

    dcache #(
        .LINE_SIZE(LINE_SIZE),
        .CACHE_SIZE(CACHE_SIZE),
        .XLEN(XLEN)
    ) dcache_dut (
        .clk(clk),
        .reset(rst_if.reset),

        .pipe_req_address  (dcache_req_if.req_address),
        .pipe_req_type     (dcache_req_if.req_operation),
        .pipe_req_size     (dcache_req_if.req_size),
        .pipe_req_valid    (dcache_req_if.req_valid),
        .pipe_word_to_store(dcache_req_if.req_store_word),
        .pipe_fetched_word (dcache_req_if.req_loaded_word),
        .pipe_req_fulfilled(dcache_req_if.req_fulfilled),

        .l2_req_address  (dcache_rsp_if.req_address),
        .l2_req_type     (dcache_rsp_if.req_operation),
        .l2_req_valid    (dcache_rsp_if.req_valid),
        .l2_word_to_store(dcache_rsp_if.req_store_word),
        .l2_fetched_word (dcache_rsp_if.req_loaded_word),
        .l2_req_fulfilled(dcache_rsp_if.req_fulfilled)
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
        assert(
            clk_config.randomize() with {
                t_period == 2;
                duty_cycle == 50;
            }
        ) else `uvm_fatal("tb_top", "Could not randomize clk_config")
        `uvm_info("tb_top", clk_config.sprint(), UVM_LOW)
        clk_enabled = 1'b1;

        uvm_config_db #(virtual cache_if)::set(
            .cntxt(null),
            .inst_name("uvm_test_top.mem_env.icache_creq_agent.*"),
            .field_name("memory_requester_if"),
            .value(icache_req_if)
        );
        uvm_config_db #(virtual higher_memory_if)::set(
            .cntxt(null),
            .inst_name("uvm_test_top.mem_env.icache_mrsp_agent.*"),
            .field_name("memory_responder_if"),
            .value(icache_rsp_if)
        );
        uvm_config_db #(virtual cache_if)::set(
            .cntxt(null),
            .inst_name("uvm_test_top.mem_env.dcache_creq_agent.*"),
            .field_name("memory_requester_if"),
            .value(dcache_req_if)
        );
        uvm_config_db #(virtual higher_memory_if)::set(
            .cntxt(null),
            .inst_name("uvm_test_top.mem_env.dcache_mrsp_agent.*"),
            .field_name("memory_responder_if"),
            .value(dcache_rsp_if)
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