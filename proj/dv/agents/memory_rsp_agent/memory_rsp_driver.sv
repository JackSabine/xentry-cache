class memory_rsp_driver extends uvm_driver #(memory_transaction);
    `uvm_component_utils(memory_rsp_driver)

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

        fork
            forever begin
                @(negedge rsp_vi.clk);
                rsp_vi.req_fulfilled <= rsp_vi.req_valid;
            end

            forever begin
                seq_item_port.get_next_item(mem_tx);

                `uvm_info(
                    "memory_driver",
                    $sformatf(
                        "Driving txn:\n%s",
                        mem_tx.convert2string()
                    ),
                    UVM_DEBUG
                )

                rsp_vi.req_loaded_word <= mem_tx.req_loaded_word;
                seq_item_port.item_done();
            end
        join
    endtask
endclass
