class cache_base_test extends uvm_test;
    `uvm_component_utils(cache_base_test)

    environment mem_env;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        uvm_root::get().set_timeout(100000ns, 1);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mem_env = environment::type_id::create(.name("mem_env"), .parent(this));
        set_transaction_type();
    endfunction

    virtual function void set_transaction_type();

    endfunction

    task reset_phase(uvm_phase phase);
        reset_seq rst_seq;

        phase.raise_objection(this);

        rst_seq = reset_seq::type_id::create(.name("rst_seq"));
        assert(rst_seq.randomize()) else `uvm_fatal(get_full_name(), "Couldn't randomize rst_seq");
        rst_seq.print();
        rst_seq.start(mem_env.rst_agent.rst_seqr);

        phase.drop_objection(this);
    endtask

    task main_phase(uvm_phase phase);
        trace_based_memory_seq mem_seq;
        memory_response_seq mem_rsp_seq;

        phase.raise_objection(this);

        mem_seq = trace_based_memory_seq::type_id::create(.name("mem_seq"));
        mem_rsp_seq = memory_response_seq::type_id::create(.name("mem_rsp_seq"));
        assert(mem_seq.randomize()) else `uvm_fatal(get_full_name(), "Couldn't randomize mem_seq")
        `uvm_info("mem_seq", mem_seq.convert2string(), UVM_NONE)
        mem_seq.print();
        fork
            mem_seq.start(mem_env.creq_agent.creq_seqr);     // Runs until complete
            mem_rsp_seq.start(mem_env.mrsp_agent.mrsp_seqr); // Runs forever
        join_any

        phase.drop_objection(this);
    endtask
endclass
