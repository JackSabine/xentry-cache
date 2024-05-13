class memory_rsp_agent extends uvm_agent;
    `uvm_component_utils(memory_rsp_agent)

    memory_rsp_sequencer hmem_seqr;
    memory_rsp_driver    hmem_drv;
    memory_rsp_monitor   hmem_mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        hmem_seqr = memory_rsp_sequencer::type_id::create(.name("hmem_seqr"), .parent(this));
        hmem_drv  = memory_rsp_driver::type_id::create(.name("hmem_drv"), .parent(this));
        hmem_mon  = memory_rsp_monitor::type_id::create(.name("hmem_mon"), .parent(this));
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        hmem_drv.seq_item_port.connect(hmem_seqr.seq_item_export);
        hmem_mon.mem_ap.connect(hmem_seqr.mem_tx_export);
    endfunction
endclass
