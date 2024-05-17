class environment extends uvm_env;
    `uvm_component_utils(environment)

    cache_req_agent creq_agent;
    memory_rsp_agent mrsp_agent;
    reset_agent rst_agent;
    scoreboard sb;

    memory_model mem_model;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mem_model = new;
        uvm_config_db #(memory_model)::set(
            .cntxt(this),
            .inst_name("*"),
            .field_name("memory_model"),
            .value(mem_model)
        );

        creq_agent  = cache_req_agent::type_id::create(.name("creq_agent"), .parent(this));
        mrsp_agent = memory_rsp_agent::type_id::create(.name("mrsp_agent"), .parent(this));
        rst_agent  = reset_agent::type_id::create(.name("rst_agent"), .parent(this));
        sb         = scoreboard::type_id::create(.name("sb"), .parent(this));
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        creq_agent.creq_mon_ap.connect(sb.aport_mon);
        creq_agent.creq_drv_ap.connect(sb.aport_drv);
    endfunction
endclass