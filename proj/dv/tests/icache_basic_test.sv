class icache_basic_test extends cache_base_test;
    `uvm_component_utils(icache_basic_test)

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void set_transaction_type();
        memory_transaction::type_id::set_type_override(icache_read_only_memory_transaction::get_type());
    endfunction
endclass
