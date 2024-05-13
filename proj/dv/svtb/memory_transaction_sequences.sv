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

    `uvm_object_utils_begin(repeated_memory_transaction_sequence)
        `uvm_field_int(address, UVM_ALL_ON)
    `uvm_object_utils_end
endclass

class higher_memory_response_seq extends uvm_sequence #(memory_transaction);
    `uvm_object_utils(higher_memory_response_seq)

    higher_memory_sequencer p_sequencer;
    memory_transaction mem_tx;

    function new (string name = "");
        super.new(name);
    endfunction

    virtual task body();
        $cast(p_sequencer, m_sequencer);
        `uvm_info(get_type_name(), $sformatf("%s is starting", get_sequence_path()), UVM_MEDIUM)

        forever begin
            // Get from the analysis port
            p_sequencer.mem_tx_fifo.get(mem_tx);

            `uvm_do_with(
                req, {
                    req.req_address     == mem_tx.req_address;
                    req.req_operation   == mem_tx.req_operation;
                    req.req_size        == mem_tx.req_size;
                    req.req_loaded_word == mem_tx.req_loaded_word;
                }
            )
        end
    endtask
endclass