class icache_basic_test extends uvm_test;
    `uvm_component_utils(icache_basic_test)

    memory_env mem_env;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        uvm_root::get().set_timeout(100000ns, 1);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mem_env = memory_env::type_id::create(.name("mem_env"), .parent(this));
        memory_transaction::type_id::set_type_override(icache_memory_transaction::get_type());
    endfunction

    task main_phase(uvm_phase phase);
        repeated_memory_transaction_seq mem_seq;
        higher_memory_response_seq hmem_rsp_seq;

        phase.raise_objection(this);

        mem_seq = repeated_memory_transaction_seq::type_id::create(.name("mem_seq"));
        hmem_rsp_seq = higher_memory_response_seq::type_id::create(.name("hmem_rsp_seq"));
        assert(mem_seq.randomize() with { mem_seq.num_transactions == 4; });
        `uvm_info("mem_seq", mem_seq.convert2string(), UVM_NONE)
        mem_seq.print();
        fork
            mem_seq.start(mem_env.mem_agent.mem_seqr);        // Runs until complete
            hmem_rsp_seq.start(mem_env.hmem_agent.hmem_seqr); // Runs forever
        join_any

        phase.drop_objection(this);
    endtask
endclass
