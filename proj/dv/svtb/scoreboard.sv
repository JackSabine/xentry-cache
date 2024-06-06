`uvm_analysis_imp_decl( _drv )
`uvm_analysis_imp_decl( _mon )

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_analysis_imp_drv #(memory_transaction, scoreboard) aport_drv;
    uvm_analysis_imp_mon #(memory_transaction, scoreboard) aport_mon;

    uvm_tlm_fifo #(memory_transaction) expfifo;
    uvm_tlm_fifo #(memory_transaction) outfifo;

    cache_wrapper cache_model;
    cache_config dut_config;
    clock_config clk_config;

    static uint32_t cache_miss_delay;
    static uint32_t cache_flush_delay;

    uint32_t total_loads;
    uint32_t total_stores;
    uint32_t total_clflushes;

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        aport_drv = new("aport_drv", this);
        aport_mon = new("aport_mon", this);
        expfifo   = new("expfifo", this);
        outfifo   = new("outfifo", this);
        cache_model = new(dut_config.cache_size, dut_config.line_size, dut_config.assoc);
    endfunction

    function new (string name, uvm_component parent);
        super.new(name, parent);
        total_loads = 0;
        total_stores = 0;
        total_clflushes = 0;

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
                total_loads++;
                resp = cache_model.read(tr.req_address);
            end

            STORE: begin
                total_stores++;
                resp = cache_model.write(tr.req_address, tr.req_store_word);
            end

            CLFLUSH: begin
                total_clflushes++;
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
        void'(expfifo.try_put(tr));
    endfunction

    function void write_mon(memory_transaction tr);
        // tr has t_issued and t_fulfilled
        `uvm_info("write_mon OUT ", tr.convert2string(), UVM_HIGH)
        void'(outfifo.try_put(tr));
    endfunction

    task run_phase(uvm_phase phase);
        memory_transaction exp_tr, out_tr;
        bit pass;

        forever begin
            `uvm_info("scoreboard run task", "WAITING for expected output", UVM_DEBUG)
            expfifo.get(exp_tr);
            `uvm_info("scoreboard run task", "WAITING for actual output", UVM_DEBUG)
            outfifo.get(out_tr);

            pass = out_tr.compare(exp_tr);

            if (exp_tr.expect_hit) pass &= out_tr.t_issued == out_tr.t_fulfilled;
            else                   pass &= out_tr.t_issued != out_tr.t_fulfilled;

            if (pass) begin
                PASS();
                `uvm_info (
                    "PASS ",
                    $sformatf({
                        "\n\n<<<<< Observed  >>>>>\n%s",
                          "\n<<<<< Predicted >>>>>\n%s\n"
                        },
                        out_tr.sprint(), exp_tr.sprint()
                    ),
                    UVM_HIGH
                )
            end else begin
                ERROR();
                `uvm_error(
                    "ERROR",
                    $sformatf({
                        "\n\n<<<<< Observed  >>>>>\n%s",
                          "\n<<<<< Predicted >>>>>\n%s\n"
                        },
                        out_tr.sprint(), exp_tr.sprint()
                    )
                )
            end
        end
    endtask

    int VECT_CNT, PASS_CNT, ERROR_CNT;

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        if (VECT_CNT && !ERROR_CNT) begin
            `uvm_info(
                "PASSED",
                $sformatf(
                    "\n\n\n*** TEST PASSED - %0d vectors ran, %0d vectors passed ***\n",
                    VECT_CNT, PASS_CNT
                ),
                UVM_LOW
            )
        end else begin
            `uvm_error(
                "FAILED",
                $sformatf(
                    "\n\n\n*** TEST FAILED - %0d vectors ran, %0d vectors passed, %0d vectors failed ***\n",
                    VECT_CNT, PASS_CNT, ERROR_CNT
                )
            )
        end
    endfunction

    function void PASS();
        VECT_CNT++;
        PASS_CNT++;
    endfunction

    function void ERROR();
        VECT_CNT++;
        ERROR_CNT++;
    endfunction

endclass