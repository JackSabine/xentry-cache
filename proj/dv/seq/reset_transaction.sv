class reset_transaction extends uvm_sequence_item;
    rand uint32_t reset_duration_in_clocks;
    rand uint32_t post_reset_delay;

    `uvm_object_utils_begin(reset_transaction)
        `uvm_field_int(reset_duration_in_clocks, UVM_ALL_ON | UVM_UNSIGNED)
        `uvm_field_int(post_reset_delay,         UVM_ALL_ON | UVM_UNSIGNED)
    `uvm_object_utils_end

    function new(string name = "");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("reset_duration_in_clocks = %0d | post_reset_delay = %0d", reset_duration_in_clocks, post_reset_delay);
    endfunction
endclass
