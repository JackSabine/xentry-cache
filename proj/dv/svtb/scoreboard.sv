`uvm_analysis_imp_decl( _icache_drv )
`uvm_analysis_imp_decl( _icache_mon )
`uvm_analysis_imp_decl( _dcache_drv )
`uvm_analysis_imp_decl( _dcache_mon )

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_analysis_imp_icache_drv #(memory_transaction, scoreboard) aport_icache_drv;
    uvm_analysis_imp_icache_mon #(memory_transaction, scoreboard) aport_icache_mon;
    uvm_analysis_imp_dcache_drv #(memory_transaction, scoreboard) aport_dcache_drv;
    uvm_analysis_imp_dcache_mon #(memory_transaction, scoreboard) aport_dcache_mon;

    uvm_tlm_fifo #(memory_transaction) icache_expected_fifo;
    uvm_tlm_fifo #(memory_transaction) icache_observed_fifo;
    uvm_tlm_fifo #(memory_transaction) dcache_expected_fifo;
    uvm_tlm_fifo #(memory_transaction) dcache_observed_fifo;

    cache_wrapper cache_model;
    cache_config dut_config;
    clock_config clk_config;

    static uint32_t cache_miss_delay;
    static uint32_t cache_flush_delay;

    uint32_t vector_count, pass_count, fail_count;
    uint32_t load_count, store_count, clflush_count;
    uint32_t icache_count, dcache_count;

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        aport_icache_drv = new("aport_icache_drv", this);
        aport_icache_mon = new("aport_icache_mon", this);
        icache_expected_fifo = new("icache_expected_fifo", this);
        icache_observed_fifo = new("icache_observed_fifo", this);

        aport_dcache_drv = new("aport_dcache_drv", this);
        aport_dcache_mon = new("aport_dcache_mon", this);
        dcache_expected_fifo = new("dcache_expected_fifo", this);
        dcache_observed_fifo = new("dcache_observed_fifo", this);

        cache_model = new(dut_config.cache_size, dut_config.line_size, dut_config.assoc);
    endfunction

    function new (string name, uvm_component parent);
        super.new(name, parent);

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

    function void predictor(memory_transaction tr, ref uvm_tlm_fifo #(memory_transaction) expected_fifo, input l1_type_e cache_type);
        // tr has t_issued
        // use to predict t_fulfilled

        cache_response_t resp;

        case (tr.req_operation)
            LOAD: begin
                load_count++;
                resp = cache_model.read(tr.req_address, cache_type);
            end

            STORE: begin
                store_count++;
                resp = cache_model.write(tr.req_address, tr.req_store_word, cache_type);
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

        `uvm_info("write_drv OUT ", tr.convert2string(), UVM_MEDIUM)
        void'(expected_fifo.try_put(tr));
    endfunction

    function void observer(memory_transaction tr, ref uvm_tlm_fifo #(memory_transaction) observed_fifo);
        // tr has t_issued and t_fulfilled
        `uvm_info("write_mon OUT ", tr.convert2string(), UVM_HIGH)
        void'(observed_fifo.try_put(tr));
    endfunction

    function void write_icache_drv(memory_transaction tr);
        predictor(tr, icache_expected_fifo, ICACHE);
    endfunction

    function void write_icache_mon(memory_transaction tr);
        observer(tr, icache_observed_fifo);
    endfunction

    function void write_dcache_drv(memory_transaction tr);
        predictor(tr, dcache_expected_fifo, DCACHE);
    endfunction

    function void write_dcache_mon(memory_transaction tr);
        observer(tr, dcache_observed_fifo);
    endfunction

    task comparer(ref uvm_tlm_fifo #(memory_transaction) expected_fifo, ref uvm_tlm_fifo #(memory_transaction) observed_fifo, input l1_type_e cache_type);
        memory_transaction expected_tx, observed_tx;
        bit pass;
        string printout_str;
        string name;

        name = $sformatf("scoreboard comparer<%s>", cache_type.name());

        forever begin
            `uvm_info(name, "WAITING for expected output", UVM_DEBUG)
            expected_fifo.get(expected_tx);
            `uvm_info(name, "WAITING for observed output", UVM_DEBUG)
            observed_fifo.get(observed_tx);

            pass = observed_tx.compare(expected_tx);

            if (expected_tx.expect_hit) pass &= (observed_tx.t_issued == observed_tx.t_fulfilled);
            else                        pass &= (observed_tx.t_issued != observed_tx.t_fulfilled);

            printout_str = $sformatf(
                {
                    "\n",
                    "OBSERVED: %s\n",
                    "EXPECTED: %s\n"
                },
                observed_tx.convert2string(), expected_tx.convert2string()
            );

            if (pass) begin
                vector_pass();
                `uvm_info("PASS: ", printout_str, UVM_HIGH)
            end else begin
                vector_fail();
                `uvm_error("FAIL: ", printout_str)
            end

            assert(expected_tx.origin == cache_type)
                else `uvm_error(name, $sformatf("Received driven transaction from incorrect origin (%s)", expected_tx.origin.name()))

            case(cache_type)
                ICACHE: icache_count++;
                DCACHE: dcache_count++;
            endcase
        end
    endtask

    task run_phase(uvm_phase phase);
        fork
            comparer(icache_expected_fifo, icache_observed_fifo, ICACHE);
            comparer(dcache_expected_fifo, dcache_observed_fifo, DCACHE);
        join
    endtask

    function void report_phase(uvm_phase phase);
        string report_str;

        super.report_phase(phase);

        report_str = $sformatf(
            {
                "* load_count:    %0d\n",
                "* store_count:   %0d\n",
                "* clflush_count: %0d\n",
                "\n",
                "* icache transactions: %0d\n",
                "* dcache transactions: %0d\n"
            },
            load_count,
            store_count,
            clflush_count,
            icache_count,
            dcache_count
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