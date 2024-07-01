class dcache_basic_test extends cache_base_test;
    `uvm_component_utils(dcache_basic_test)

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function l1_type_e choose_active_agent();
        return DCACHE;
    endfunction

    virtual function void set_transaction_type();
        `uvm_info(get_name(), "Overriding types", UVM_LOW)
        memory_transaction::type_id::set_type_override(dcache_transaction::get_type());
    endfunction
endclass
