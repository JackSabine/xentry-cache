class memory_rsp_agent extends uvm_agent;
    `uvm_component_utils(memory_rsp_agent)

    memory_rsp_sequencer mrsp_seqr;
    memory_rsp_driver    mrsp_drv;
    memory_rsp_monitor   mrsp_mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        mrsp_seqr = memory_rsp_sequencer::type_id::create(.name("mrsp_seqr"), .parent(this));
        mrsp_drv  = memory_rsp_driver::type_id::create(.name("mrsp_drv"), .parent(this));
        mrsp_mon  = memory_rsp_monitor::type_id::create(.name("mrsp_mon"), .parent(this));
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mrsp_drv.seq_item_port.connect(mrsp_seqr.seq_item_export);
        mrsp_mon.mrsp_ap.connect(mrsp_seqr.mem_tx_export);
    endfunction
endclass
