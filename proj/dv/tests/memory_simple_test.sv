class memory_simple_test extends uvm_test;
    `uvm_component_utils(memory_simple_test)

    memory_env mem_env;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mem_env = memory_env::type_id::create(.name("mem_env"), .parent(this));
        memory_transaction::type_id::set_type_override(read_only_memory_transaction::get_type());
    endfunction

    task main_phase(uvm_phase phase);
        repeated_memory_transaction_sequence mem_seq;

        mem_seq = repeated_memory_transaction_sequence::type_id::create(.name("mem_seq"));
        assert(mem_seq.randomize());
        `uvm_info("mem_seq", mem_seq.convert2string(), UVM_NONE)
        mem_seq.set_starting_phase(phase);
        mem_seq.set_automatic_phase_objection(.value(1));
        mem_seq.start(mem_env.mem_agent.mem_seqr);
    endtask
endclass
