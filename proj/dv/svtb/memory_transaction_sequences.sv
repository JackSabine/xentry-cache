class one_memory_transaction_sequence extends uvm_sequence #(memory_transaction);
    `uvm_object_utils(one_memory_transaction_sequence)

    function new (string name = "");
        super.new(name);
    endfunction

    task body();
        memory_transaction mem_tx;
        mem_tx = memory_transaction::type_id::create(.name("mem_tx"), .contxt(get_full_name()));
        start_item(mem_tx);
        assert(mem_tx.randomize());
        finish_item(mem_tx);
    endtask
endclass

class repeated_memory_transaction_sequence extends uvm_sequence #(memory_transaction);
    rand uint32_t num_transactions;
    uint32_t address;

    constraint num_transactions_constraint {
        num_transactions inside {[2:4]};
    }

    function new (string name = "");
        super.new(name);
    endfunction

    task body();
        memory_transaction mem_tx;

        mem_tx = memory_transaction::type_id::create(.name("mem_tx"), .contxt(get_full_name()));
        assert(mem_tx.randomize());
        address = mem_tx.address;

        repeat(num_transactions) begin
            mem_tx = memory_transaction::type_id::create(.name("mem_tx"), .contxt(get_full_name()));
            start_item(mem_tx);
            assert(mem_tx.randomize() with { mem_tx.address == address; });
            finish_item(mem_tx);
        end
    endtask

    `uvm_object_utils_begin(repeated_memory_transaction_sequence)
        `uvm_field_int(address, UVM_ALL_ON)
    `uvm_object_utils_end
endclass
