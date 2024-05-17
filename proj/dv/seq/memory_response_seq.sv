class memory_response_seq extends uvm_sequence #(memory_transaction);
    `uvm_object_utils(memory_response_seq)

    memory_rsp_sequencer p_sequencer;
    memory_transaction mem_tx;

    function new (string name = "");
        super.new(name);
    endfunction

    virtual task body();
        $cast(p_sequencer, m_sequencer);
        `uvm_info(get_type_name(), $sformatf("%s is starting", get_sequence_path()), UVM_MEDIUM)

        forever begin
            // Get from the analysis port
            p_sequencer.mem_tx_fifo.get(mem_tx);

            `uvm_do_with(
                req, {
                    req.req_address     == mem_tx.req_address;
                    req.req_operation   == mem_tx.req_operation;
                    req.req_size        == mem_tx.req_size;
                    req.req_loaded_word == mem_tx.req_loaded_word;
                }
            )
        end
    endtask
endclass
