class higher_memory_sequencer extends uvm_sequencer #(memory_transaction);
    `uvm_component_utils(higher_memory_sequencer)

    uvm_tlm_analysis_fifo #(memory_transaction) mem_tx_fifo;
    uvm_analysis_export #(memory_transaction) mem_tx_export;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mem_tx_fifo = new("mem_tx_fifo", this);
        mem_tx_export = new("mem_tx_export", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mem_tx_export.connect(mem_tx_fifo.analysis_export);
    endfunction
endclass