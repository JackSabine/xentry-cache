class icache_basic_test extends cache_base_test;
    `uvm_component_utils(icache_basic_test)

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function l1_type_e choose_active_agent();
        return ICACHE;
    endfunction

    virtual function void set_transaction_type();
        `uvm_info(get_name(), "Overriding types", UVM_LOW)
        memory_transaction::type_id::set_type_override(icache_transaction::get_type());
    endfunction
endclass
