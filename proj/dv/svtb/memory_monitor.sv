class memory_monitor extends uvm_monitor;
    `uvm_component_utils(memory_monitor)

    uvm_analysis_port #(memory_transaction) mem_ap;

    virtual memory_if req_vi;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        assert(uvm_config_db #(virtual memory_if)::get(
            .cntxt(this),
            .inst_name(""),
            .field_name("memory_requester_if"),
            .value(req_vi)
        ));
    endfunction

    task run_phase(uvm_phase phase);
        memory_transaction mem_tx;

        forever begin
            @(posedge req_vi.clk);

            if (req_vi.req_valid) begin
                mem_tx = memory_transaction::type_id::create(.name("mem_tx"), .contxt(get_full_name()));

                mem_tx.address       = req_vi.address;
                mem_tx.op            = memory_operation_e'(req_vi.op);
                mem_tx.size          = memory_operation_size_e'(req_vi.size);
                mem_tx.data_to_write = req_vi.word_to_store;

                @(posedge req_vi.req_fulfilled);
                mem_tx.data_read     = req_vi.fetched_word;

                mem_ap.write(mem_tx);
            end
        end
   endtask

endclass