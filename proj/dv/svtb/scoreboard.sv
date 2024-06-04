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
    endfunction

    function void write_drv(memory_transaction tr);
        // tr has t_issued
        // use to predict t_fulfilled

        case (tr.req_operation)
            LOAD: begin
                total_loads++;
                tr.req_loaded_word = cache_model.read(tr.req_address);
            end

            STORE: begin
                total_stores++;
            end

            CLFLUSH: begin
                total_clflushes++;
            end
        endcase

        `uvm_info("write_drv OUT ", tr.convert2string(), UVM_HIGH)
        void'(expfifo.try_put(tr));
    endfunction

    function void write_mon(memory_transaction tr);
        // tr has t_fulfilled
        `uvm_info("write_mon OUT ", tr.convert2string(), UVM_HIGH)
        void'(outfifo.try_put(tr));
    endfunction

    task run_phase(uvm_phase phase);
        memory_transaction exp_tr, out_tr;
        forever begin
            `uvm_info("scoreboard run task", "WAITING for expected output", UVM_DEBUG)
            expfifo.get(exp_tr);
            `uvm_info("scoreboard run task", "WAITING for actual output", UVM_DEBUG)
            outfifo.get(out_tr);
            if (out_tr.compare(exp_tr)) begin
                PASS();
                `uvm_info (
                    "PASS ",
                    $sformatf(
                        {
                            "\n** Actual  =%s",
                            "\n** Expected=%s"
                        },
                        out_tr.convert2string(), exp_tr.convert2string()
                    ),
                    UVM_HIGH
                )
            end else begin
                ERROR();
                `uvm_error(
                    "ERROR",
                    $sformatf(
                        {
                            "\n** Actual  =%s",
                            "\n** Expected=%s"
                        },
                        out_tr.convert2string(), exp_tr.convert2string()
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