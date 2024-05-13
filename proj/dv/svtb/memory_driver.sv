class memory_driver extends uvm_driver #(memory_transaction);
    `uvm_component_utils(memory_driver)

    uvm_analysis_port #(memory_transaction) mem_ap;

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
        mem_ap = new(.name("mem_ap"), .parent(this));
    endfunction

    task run_phase(uvm_phase phase);
        memory_transaction mem_tx;

        #200;

        forever begin
            @(posedge req_vi.clk);
            req_vi.req_valid <= 1'b0;
            seq_item_port.get_next_item(mem_tx);

            @(posedge req_vi.clk);
            `uvm_info(
                "memory_driver",
                $sformatf(
                    "Driving txn: %s",
                    mem_tx.convert2string()
                ),
                UVM_MEDIUM
            )
            req_vi.req_valid      <= 1'b1;
            req_vi.req_address    <= mem_tx.req_address;
            req_vi.req_operation  <= mem_tx.req_operation;
            req_vi.req_size       <= mem_tx.req_size;
            req_vi.req_store_word <= mem_tx.req_store_word;
            seq_item_port.item_done();
            mem_ap.write(mem_tx);

            while (!req_vi.req_fulfilled) begin
                @(posedge req_vi.clk);
            end
        end
   endtask
endclass
