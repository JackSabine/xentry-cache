class higher_memory_driver extends uvm_driver #(memory_transaction);
    `uvm_component_utils(higher_memory_driver)

    virtual higher_memory_if rsp_vi;

    function new (string name, uvm_component parent);
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
    endfunction

    task run_phase(uvm_phase phase);
        memory_transaction mem_tx;

        forever begin
            rsp_vi.req_fulfilled <= 1'b0;
            seq_item_port.get_next_item(mem_tx);

            `uvm_info(
                "memory_driver",
                $sformatf(
                    "Driving txn:\n%s",
                    mem_tx.convert2string()
                ),
                UVM_MEDIUM
            )

            rsp_vi.req_fulfilled <= 1'b1;
            rsp_vi.req_loaded_word <= mem_tx.req_loaded_word;
            seq_item_port.item_done();
            @(posedge rsp_vi.clk);
        end
    endtask
endclass
