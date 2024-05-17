class cache_req_monitor extends uvm_monitor;
    `uvm_component_utils(cache_req_monitor)

    uvm_analysis_port #(memory_transaction) creq_ap;

    virtual cache_if req_vi;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        assert(uvm_config_db #(virtual cache_if)::get(
            .cntxt(this),
            .inst_name(""),
            .field_name("memory_requester_if"),
            .value(req_vi)
        ));
        creq_ap = new(.name("creq_ap"), .parent(this));
    endfunction

    task run_phase(uvm_phase phase);
        memory_transaction mem_tx;

        forever begin
            @(posedge req_vi.clk);

            if (req_vi.req_valid) begin
                mem_tx = memory_transaction::type_id::create(.name("mem_tx"), .contxt(get_full_name()));

                mem_tx.req_address    = req_vi.req_address;
                mem_tx.req_operation  = memory_operation_e'(req_vi.req_operation);
                mem_tx.req_size       = memory_operation_size_e'(req_vi.req_size);
                mem_tx.req_store_word = req_vi.req_store_word;

                `uvm_info(get_full_name(), "req_valid seen, awaiting req_fulfilled", UVM_DEBUG)

                if (!req_vi.req_fulfilled) begin
                    while (!req_vi.req_fulfilled) begin
                        @(posedge req_vi.clk);
                    end
                end

                mem_tx.req_loaded_word = req_vi.req_loaded_word;

                `uvm_info(
                    get_full_name(),
                    $sformatf(
                        "Observed txn: %s",
                        mem_tx.convert2string()
                    ),
                    UVM_DEBUG
                )
                creq_ap.write(mem_tx);
            end
        end
    endtask

    task shutdown_phase(uvm_phase phase);
        phase.raise_objection(this);

        if (req_vi.req_fulfilled) begin
            while (req_vi.req_fulfilled) begin
                @(posedge req_vi.clk);
            end
        end

        repeat(4) @(posedge req_vi.clk);

        phase.drop_objection(this);
    endtask
endclass
