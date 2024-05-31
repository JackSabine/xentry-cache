class cache_base_test extends uvm_test;
    `uvm_component_utils(cache_base_test)

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
        set_transaction_type();
    endfunction

    virtual function void set_transaction_type();

    endfunction

    task reset_phase(uvm_phase phase);
        reset_seq rst_seq;

        phase.raise_objection(this);

        rst_seq = reset_seq::type_id::create(.name("rst_seq"));
        assert(rst_seq.randomize());
        rst_seq.print();
        rst_seq.start(mem_env.rst_agent.rst_seqr);

        phase.drop_objection(this);
    endtask

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
