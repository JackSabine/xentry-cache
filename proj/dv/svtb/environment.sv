class memory_env extends uvm_env;
    `uvm_component_utils(memory_env)

    cache_req_agent mem_agent;
    memory_rsp_agent hmem_agent;
    memory_scoreboard mem_sb;

    memory_model mem_model;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mem_model = new;
        uvm_config_db #(memory_model)::set(
            .cntxt(this),
            .inst_name("hmem_agent*"),
            .field_name("memory_model"),
            .value(mem_model)
        );

        mem_agent  = cache_req_agent::type_id::create(.name("mem_agent"), .parent(this));
        hmem_agent = memory_rsp_agent::type_id::create(.name("hmem_agent"), .parent(this));
        mem_sb     = memory_scoreboard::type_id::create(.name("mem_sb"), .parent(this));
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mem_agent.mon_mem_ap.connect(mem_sb.aport_mon);
        mem_agent.drv_mem_ap.connect(mem_sb.aport_drv);
    endfunction
endclass