class one_memory_transaction_seq extends uvm_sequence #(memory_transaction);
    `uvm_object_utils(one_memory_transaction_seq)

    function new (string name = "");
        super.new(name);
    endfunction

    task body();
        memory_transaction mem_tx;
        mem_tx = memory_transaction::type_id::create(.name("mem_tx"), .contxt(get_full_name()));
        start_item(mem_tx);
        assert(mem_tx.randomize()) else `uvm_fatal(get_full_name(), "Couldn't randomize mem_tx");
        finish_item(mem_tx);
    endtask
endclass
