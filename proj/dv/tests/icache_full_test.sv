class icache_full_test extends cache_base_test;
    `uvm_component_utils(icache_full_test)

    virtual function void set_transaction_type();
        memory_transaction::type_id::set_type_override(icache_memory_transaction::get_type());
    endfunction
endclass
