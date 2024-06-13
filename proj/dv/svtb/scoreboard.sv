`uvm_analysis_imp_decl( _drv )
`uvm_analysis_imp_decl( _mon )

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_analysis_imp_drv #(memory_transaction, scoreboard) aport_drv;
    uvm_analysis_imp_mon #(memory_transaction, scoreboard) aport_mon;

    uvm_tlm_fifo #(memory_transaction) expected_fifo;
    uvm_tlm_fifo #(memory_transaction) observed_fifo;

    cache_wrapper cache_model;
    cache_config dut_config;
    clock_config clk_config;

    static uint32_t cache_miss_delay;
    static uint32_t cache_flush_delay;

    uint32_t vector_count, pass_count, fail_count;
    uint32_t load_count, store_count, clflush_count;

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        aport_drv = new("aport_drv", this);
        aport_mon = new("aport_mon", this);
        expected_fifo = new("expected_fifo", this);
        observed_fifo = new("observed_fifo", this);
        cache_model = new(dut_config.cache_size, dut_config.line_size, dut_config.assoc);
    endfunction

    function new (string name, uvm_component parent);
        super.new(name, parent);
        load_count = 0;
        store_count = 0;
        clflush_count = 0;

        assert(uvm_config_db #(cache_config)::get(
            .cntxt(null),
            .inst_name("*"),
            .field_name("cache_config"),
            .value(dut_config)
        )) else `uvm_fatal(get_full_name(), "Couldn't get cache_config from config db")

        assert(uvm_config_db #(clock_config)::get(
            .cntxt(null),
            .inst_name("*"),
            .field_name("clock_config"),
            .value(clk_config)
        )) else `uvm_fatal(get_full_name(), "Couldn't get clock_config from config db")
    endfunction

    function void write_drv(memory_transaction tr);
        // tr has t_issued
        // use to predict t_fulfilled

        cache_response_t resp;

        case (tr.req_operation)
            LOAD: begin
                load_count++;
                resp = cache_model.read(tr.req_address);
            end

            STORE: begin
                store_count++;
                resp = cache_model.write(tr.req_address, tr.req_store_word);
            end

            CLFLUSH: begin
                clflush_count++;
            end
        endcase

        case (tr.req_operation) inside
            LOAD, STORE: begin
                tr.req_loaded_word = resp.req_word;
                tr.expect_hit = resp.is_hit;
                if (tr.expect_hit) begin
                    tr.t_fulfilled = tr.t_issued;
                end
            end
        endcase

        tr.t_issued    += clk_config.t_period;
        tr.t_fulfilled += clk_config.t_period;

        `uvm_info("write_drv OUT ", tr.convert2string(), UVM_HIGH)
        void'(expected_fifo.try_put(tr));
    endfunction

    function void write_mon(memory_transaction tr);
        // tr has t_issued and t_fulfilled
        `uvm_info("write_mon OUT ", tr.convert2string(), UVM_HIGH)
        void'(observed_fifo.try_put(tr));
    endfunction

    task run_phase(uvm_phase phase);
        memory_transaction expected_tx, observed_tx;
        bit pass;

        string printout_str;

        forever begin
            `uvm_info("scoreboard run task", "WAITING for expected output", UVM_DEBUG)
            expected_fifo.get(expected_tx);
            `uvm_info("scoreboard run task", "WAITING for observed output", UVM_DEBUG)
            observed_fifo.get(observed_tx);

            pass = observed_tx.compare(expected_tx);

            if (expected_tx.expect_hit) pass &= observed_tx.t_issued == observed_tx.t_fulfilled;
            else                        pass &= observed_tx.t_issued != observed_tx.t_fulfilled;

            printout_str = $sformatf(
                {
                    "\n\n<<<<< Observed  >>>>>\n%s",
                    "\n<<<<< Expected >>>>>\n%s\n"
                },
                observed_tx.sprint(), expected_tx.sprint()
            );

            if (pass) begin
                vector_pass();
                `uvm_info("PASS: ", printout_str, UVM_HIGH)
            end else begin
                vector_fail();
                `uvm_error("FAIL: ", printout_str)
            end
        end
    endtask

    function void report_phase(uvm_phase phase);
        string report_str;

        super.report_phase(phase);

        report_str = $sformatf(
            {
                "* load_count:    %0d\n",
                "* store_count:   %0d\n",
                "* clflush_count: %0d\n"
            },
            load_count,
            store_count,
            clflush_count
        );

        if ((vector_count != 0) && (fail_count == 0)) begin
            report_str = {
                $sformatf(
                    "\n\n\n*** TEST PASSED - %0d vectors ran, %0d vectors passed ***\n",
                    vector_count, pass_count
                ),
                report_str
            };

            `uvm_info("PASSED", report_str, UVM_NONE)
        end else begin
            report_str = {
                $sformatf(
                    "\n\n\n*** TEST FAILED - %0d vectors ran, %0d vectors passed, %0d vectors failed ***\n",
                    vector_count, pass_count, fail_count
                ),
                report_str
            };

            `uvm_error("FAILED", report_str)
        end
    endfunction

    function void vector_pass();
        vector_count++;
        pass_count++;
    endfunction

    function void vector_fail();
        vector_count++;
        fail_count++;
    endfunction

endclass