class word_masked_trace_based_memory_seq extends trace_based_memory_seq;
    `uvm_object_utils(word_masked_trace_based_memory_seq)

    function new (string name = "");
        super.new(name);
    endfunction

    virtual function uint32_t mask_address(uint32_t address);
        // word-masked seq only allows for byte indices 2'b00
        return address & (~32'b11);
    endfunction
endclass
