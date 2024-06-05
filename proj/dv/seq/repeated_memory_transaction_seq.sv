class repeated_memory_transaction_seq extends uvm_sequence #(memory_transaction);
    rand uint32_t num_transactions;
    rand uint32_t block_address;
    uint32_t block_mask;
    uint32_t offset_mask;

    cache_config dut_config;

    `uvm_object_utils_begin(repeated_memory_transaction_seq)
        `uvm_field_int(num_transactions, UVM_ALL_ON)
        `uvm_field_int(block_address,    UVM_ALL_ON)
        `uvm_field_int(block_mask,       UVM_ALL_ON | UVM_NOPRINT)
        `uvm_field_int(offset_mask,      UVM_ALL_ON | UVM_NOPRINT)
    `uvm_object_utils_end

    constraint num_transactions_constraint {
        num_transactions inside {[2:4]};
    }

    function new (string name = "");
        super.new(name);

        assert(uvm_config_db #(cache_config)::get(
            .cntxt(null),
            .inst_name("*"),
            .field_name("cache_config"),
            .value(dut_config)
        )) else `uvm_fatal(get_full_name(), "Couldn't get cache_config from config db")
    endfunction

    function void generate_block_mask_and_offset_mask(uint32_t block_size);
        uint32_t mask;

        mask = $clog2(block_size); // block_size = 32 --> 5
        mask = (1 << mask);        // (1 << 5) --> 00100000
        mask = (mask - 1);         // (00100000 - 1) --> 00011111 (five 1's)

        offset_mask = mask;
        block_mask = ~mask;        // (~00011111) --> 11100000
    endfunction

    function void post_randomize();
        generate_block_mask_and_offset_mask(dut_config.line_size);

        block_address = block_address & block_mask;
    endfunction

    task body();
        memory_transaction mem_tx;

        `uvm_info(get_type_name(), $sformatf("%s is starting", get_sequence_path()), UVM_MEDIUM)

        repeat(num_transactions) begin
            mem_tx = memory_transaction::type_id::create(.name("mem_tx"), .contxt(get_full_name()));
            start_item(mem_tx);
            assert(
                mem_tx.randomize() with {
                    mem_tx.req_address inside {[block_address : block_address + offset_mask]};
                }
            ) else `uvm_fatal(get_full_name(), "Couldn't successfully randomize mem_tx")
            `uvm_info(get_full_name(), mem_tx.sprint(), UVM_MEDIUM)
            finish_item(mem_tx);
        end
    endtask
endclass
