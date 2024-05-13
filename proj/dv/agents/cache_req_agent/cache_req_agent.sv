class cache_req_agent extends uvm_agent;
    `uvm_component_utils(cache_req_agent)

    uvm_analysis_port #(memory_transaction) mon_mem_ap;
    uvm_analysis_port #(memory_transaction) drv_mem_ap;

    cache_req_sequencer mem_seqr;
    cache_req_driver    mem_drv;
    cache_req_monitor   mem_mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        mon_mem_ap = new(.name("mon_mem_ap"), .parent(this));
        drv_mem_ap = new(.name("drv_mem_ap"), .parent(this));
        mem_seqr = cache_req_sequencer::type_id::create(.name("mem_seqr"), .parent(this));
        mem_drv  = cache_req_driver::type_id::create(.name("mem_drv"), .parent(this));
        mem_mon  = cache_req_monitor::type_id::create(.name("mem_mon"), .parent(this));
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mem_drv.seq_item_port.connect(mem_seqr.seq_item_export);
        mem_mon.mem_ap.connect(mon_mem_ap);
        mem_drv.mem_ap.connect(drv_mem_ap);
    endfunction
endclass
