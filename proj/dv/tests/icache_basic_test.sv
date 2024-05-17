class icache_basic_test extends uvm_test;
    `uvm_component_utils(icache_basic_test)

    environment env;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        uvm_root::get().set_timeout(100000ns, 1);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = environment::type_id::create(.name("env"), .parent(this));
        memory_transaction::type_id::set_type_override(icache_memory_transaction::get_type());
    endfunction

    task reset_phase(uvm_phase phase);
        reset_seq rst_seq;

        phase.raise_objection(this);

        rst_seq = reset_seq::type_id::create(.name("rst_seq"));
        assert(rst_seq.randomize());
        rst_seq.print();
        rst_seq.start(env.rst_agent.rst_seqr);

        phase.drop_objection(this);
    endtask

    task main_phase(uvm_phase phase);
        repeated_memory_transaction_seq mem_seq;
        memory_response_seq mem_rsp_seq;

        phase.raise_objection(this);

        mem_seq = repeated_memory_transaction_seq::type_id::create(.name("mem_seq"));
        mem_rsp_seq = memory_response_seq::type_id::create(.name("mem_rsp_seq"));
        assert(mem_seq.randomize() with { mem_seq.num_transactions == 4; });
        `uvm_info("mem_seq", mem_seq.convert2string(), UVM_NONE)
        mem_seq.print();
        fork
            mem_seq.start(env.creq_agent.creq_seqr);      // Runs until complete
            mem_rsp_seq.start(env.mrsp_agent.mrsp_seqr); // Runs forever
        join_any

        phase.drop_objection(this);
    endtask
endclass
