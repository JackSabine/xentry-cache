class memory_rsp_monitor extends uvm_monitor;
    `uvm_component_utils(memory_rsp_monitor)

    uvm_analysis_port #(memory_transaction) mem_ap;

    virtual higher_memory_if rsp_vi;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        assert(uvm_config_db #(virtual higher_memory_if)::get(
            .cntxt(this),
            .inst_name(""),
            .field_name("memory_responder_if"),
            .value(rsp_vi)
        ));
        mem_ap = new(.name("mem_ap"), .parent(this));
    endfunction

    task run_phase(uvm_phase phase);
        memory_transaction mem_tx;
        uint32_t loaded_word;

        loaded_word = 32'hABCD_0000;

        forever begin
            @(posedge rsp_vi.clk);

            if (rsp_vi.req_valid) begin
                mem_tx = memory_transaction::type_id::create(.name("mem_tx"), .contxt(get_full_name()));

                mem_tx.req_address    = rsp_vi.req_address;
                mem_tx.req_operation  = memory_operation_e'(rsp_vi.req_operation);
                mem_tx.req_size       = WORD;
                mem_tx.req_store_word = rsp_vi.req_store_word;

                // MODEL LOOKUP
                if (mem_tx.req_operation == STORE) begin
                    // Update our memory model
                    // TODO
                end else if (mem_tx.req_operation == LOAD) begin
                    // Read from our memory model
                    // TODO
                    mem_tx.req_loaded_word = loaded_word++;
                end

                `uvm_info(
                    "higher_memory_monitor",
                    $sformatf("Received request from cache:\n%s", mem_tx.convert2string()),
                    UVM_MEDIUM
                )
                mem_ap.write(mem_tx);
            end
        end
   endtask

endclass
