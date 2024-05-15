class memory_rsp_monitor extends uvm_monitor;
    `uvm_component_utils(memory_rsp_monitor)

    uvm_analysis_port #(memory_transaction) mem_ap;

    virtual higher_memory_if rsp_vi;

    memory_model mem_model;

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
        assert(uvm_config_db #(memory_model)::get(
            .cntxt(this),
            .inst_name(""),
            .field_name("memory_model"),
            .value(mem_model)
        )) else `uvm_fatal(get_full_name(), "Couldn't get memory_model from config db")
        mem_ap = new(.name("mem_ap"), .parent(this));
    endfunction

    task run_phase(uvm_phase phase);
        memory_transaction mem_tx;

        forever begin
            @(negedge rsp_vi.clk);

            if (rsp_vi.req_valid) begin
                mem_tx = memory_transaction::type_id::create(.name("mem_tx"), .contxt(get_full_name()));

                mem_tx.req_address    = rsp_vi.req_address;
                mem_tx.req_operation  = memory_operation_e'(rsp_vi.req_operation);
                mem_tx.req_size       = WORD;
                mem_tx.req_store_word = rsp_vi.req_store_word;

                if (mem_tx.req_operation == STORE) begin
                    mem_model.write(mem_tx.req_address, mem_tx.req_store_word);
                end else if (mem_tx.req_operation == LOAD) begin
                    mem_tx.req_loaded_word = mem_model.read(mem_tx.req_address);
                end

                `uvm_info(
                    get_full_name(),
                    $sformatf("Received request from cache:\n%s", mem_tx.convert2string()),
                    UVM_DEBUG
                )
                mem_ap.write(mem_tx);
            end
        end
   endtask

endclass
