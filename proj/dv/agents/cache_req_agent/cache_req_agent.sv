class cache_req_agent extends uvm_agent;
    `uvm_component_utils(cache_req_agent)

    uvm_analysis_port #(memory_transaction) creq_mon_ap;
    uvm_analysis_port #(memory_transaction) creq_drv_ap;

    cache_req_sequencer creq_seqr;
    cache_req_driver    creq_drv;
    cache_req_monitor   creq_mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        creq_mon_ap = new(.name("creq_mon_ap"), .parent(this));
        creq_drv_ap = new(.name("creq_drv_ap"), .parent(this));
        creq_seqr = cache_req_sequencer::type_id::create(.name("creq_seqr"), .parent(this));
        creq_drv  = cache_req_driver::type_id::create(.name("creq_drv"), .parent(this));
        creq_mon  = cache_req_monitor::type_id::create(.name("creq_mon"), .parent(this));
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        creq_drv.seq_item_port.connect(creq_seqr.seq_item_export);
        creq_mon.creq_ap.connect(creq_mon_ap);
        creq_drv.creq_ap.connect(creq_drv_ap);
    endfunction
endclass
