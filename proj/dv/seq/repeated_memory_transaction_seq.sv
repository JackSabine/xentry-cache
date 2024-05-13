class repeated_memory_transaction_seq extends uvm_sequence #(memory_transaction);
    rand uint32_t num_transactions;
    uint32_t address;

    `uvm_object_utils_begin(repeated_memory_transaction_seq)
        `uvm_field_int(address, UVM_ALL_ON)
    `uvm_object_utils_end

    constraint num_transactions_constraint {
        num_transactions inside {[2:4]};
    }

    function new (string name = "");
        super.new(name);
    endfunction

    task body();
        memory_transaction mem_tx;

        `uvm_info(get_type_name(), $sformatf("%s is starting", get_sequence_path()), UVM_MEDIUM)

        mem_tx = memory_transaction::type_id::create(.name("mem_tx"), .contxt(get_full_name()));
        assert(mem_tx.randomize());
        address = mem_tx.req_address;

        repeat(num_transactions) begin
            mem_tx = memory_transaction::type_id::create(.name("mem_tx"), .contxt(get_full_name()));
            start_item(mem_tx);
            assert(mem_tx.randomize() with { mem_tx.req_address == address; });
            finish_item(mem_tx);
        end
    endtask
endclass
