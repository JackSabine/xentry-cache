class reset_agent extends uvm_agent;
    `uvm_component_utils(reset_agent)

    reset_sequencer rst_seqr;
    reset_driver    rst_drv;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        rst_seqr = reset_sequencer::type_id::create(.name("rst_seqr"), .parent(this));
        rst_drv  = reset_driver::type_id::create(.name("rst_drv"), .parent(this));
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        rst_drv.seq_item_port.connect(rst_seqr.seq_item_export);
    endfunction
endclass
