`uvm_analysis_imp_decl( _drv )
`uvm_analysis_imp_decl( _mon )

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_analysis_imp_drv #(memory_transaction, scoreboard) aport_drv;
    uvm_analysis_imp_mon #(memory_transaction, scoreboard) aport_mon;

    uvm_tlm_fifo #(memory_transaction) expfifo;
    uvm_tlm_fifo #(memory_transaction) outfifo;

    memory_model mem_model;
    cache_model cch_model;

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

        assert(uvm_config_db #(memory_model)::get(
            .cntxt(this),
            .inst_name(""),
            .field_name("memory_model"),
            .value(mem_model)
        )) else `uvm_fatal(get_full_name(), "Couldn't get memory_model from config db")
    endfunction

    function new (string name, uvm_component parent);
        super.new(name, parent);
        total_loads = 0;
        total_stores = 0;
        total_clflushes = 0;
    endfunction

    function void write_drv(memory_transaction tr);
        // tr has t_issued
        // use to predict t_fulfilled

        tr.t_fulfilled = tr.t_issued;

        case (tr.req_type) inside
            LOAD, STORE: begin
                if (!cch_model.is_cached(tr.req_address)) begin
                    tr.t_fulfilled += cache_miss_delay;

                    if (cch_model.is_victim_dirty(tr.req_address)) begin
                        tr.t_fulfilled += cache_miss_delay; // FIXME
                        cch_model.clear_dirty(tr.req_address);
                        // Read out cacheline and dump to mem_model
                        cch_model.evict(tr.req_address);
                    end

                    cch_model.install(tr.req_address, mem_model.read_cacheline(tr.req_address));
                end

            end

            CLFLUSH: begin
                if (cch_model.is_cached(tr.req_address) && cch_model.is_dirty(tr.req_address)) begin
                    tr.t_fulfilled += cache_flush_delay;
                    cch_model.clear_dirty(tr.req_address);
                end

                cch_model.evict_block(tr.req_address);
            end
        endcase

        case (tr.req_type)
            LOAD: begin
                // FIXME use similar code to select a byte/half/word from the cacheline
                /*
                function uint32_t generate_expected_value(uint32_t block_address, bit[WORD_SELECT_SIZE-1:0] word_offset, bit[1:0] byte_offset);
                    uint32_t mask;
                    uint32_t word_address;

                    unique case (pipe_req_size)
                        BYTE: mask = gen_bitmask(8);
                        HALF: mask = gen_bitmask(16);
                        WORD: mask = gen_bitmask(32);
                    endcase

                    word_address = gen_word_address(block_address, word_offset, '0);

                    return (model_memory[word_address] >> (8 * byte_offset)) & mask;
                endfunction
                */

                // tr.req_loaded_word = cch_model.read_cached_word(tr.req_address);
            end

            STORE: begin
                // FIXME use similar code to write a byte/half/word to the cacheline
                /*
                function void update_model_memory(uint32_t pipe_word_to_store, uint32_t block_address, bit[WORD_SELECT_SIZE-1:0] word_offset, bit[BYTE_SELECT_SIZE-1:0] byte_offset, memory_operation_size_e pipe_req_size);
                    uint32_t word_address;
                    uint32_t mask;
                    uint32_t temp;

                    unique case (pipe_req_size)
                        BYTE: mask = gen_bitmask(8);
                        HALF: mask = gen_bitmask(16);
                        WORD: mask = gen_bitmask(32);
                    endcase

                    word_address = gen_word_address(block_address, word_offset, '0);

                    `ifdef DEBUG_PRINT
                    $display("Performing a %0s store to word address 0x%08x (byte %02b) with value 0x%08x", pipe_req_size.name, word_address, byte_offset, pipe_word_to_store);
                    `endif

                    temp = model_memory[word_address];
                    temp = temp & ~(mask << (8 * byte_offset));
                    temp = temp | (pipe_word_to_store << (8 * byte_offset));

                    model_memory[word_address] = temp;
                endfunction
                */
                tr.req_loaded_word = tr.req_store_word;
            end

            CLFLUSH: begin
                // Nothing to do...
            end
        endcase

        case (tr.req_operation)
            LOAD: total_loads++;
            STORE: total_stores++;
            CLFLUSH: total_clflushes++;
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