class memory_driver extends uvm_driver #(memory_transaction);
    `uvm_component_utils(memory_driver)

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
            seq_item_port.get_next_item(mem_tx);
            req_vi.req_valid <= 1'b0;

            @(posedge req_vi.clk);
            req_vi.address       <= mem_tx.address;
            req_vi.op            <= mem_tx.op;
            req_vi.size          <= mem_tx.size;
            req_vi.word_to_store <= mem_tx.data_to_write;
            seq_item_port.item_done();
            mem_ap.write(mem_tx);

            @(posedge req_vi.req_fulfilled);
        end
   endtask
endclass
