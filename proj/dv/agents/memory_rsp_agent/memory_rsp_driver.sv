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
        )) else `uvm_fatal(get_full_name(), "Couldn't get memory_responder_if from config db")
    endfunction

    task run_phase(uvm_phase phase);
        memory_transaction mem_tx;
        bit is_hit;

        fork
            forever begin
                @(negedge rsp_vi.clk or is_hit);
                rsp_vi.req_fulfilled <= rsp_vi.req_valid & is_hit;
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

                assert(std::randomize(is_hit) with {
                    is_hit dist {
                        1 := 60,
                        0 := 40
                    };
                }) else `uvm_fatal(get_full_name(), "Couldn't randomize is_hit")

                if (!is_hit) begin
                    repeat(2) @(negedge rsp_vi.clk);
                    is_hit = 1'b1;
                end

                mem_tx.t_fulfilled = $time();

                rsp_vi.req_loaded_word <= mem_tx.req_loaded_word;
                seq_item_port.item_done();
            end
        join
    endtask
endclass
