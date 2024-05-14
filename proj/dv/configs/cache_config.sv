class cache_config extends uvm_object;
    uint32_t line_size;
    uint32_t cache_size;
    uint32_t assoc;

    `uvm_object_utils_begin(cache_config)
        `uvm_field_int(line_size,  UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(cache_size, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(assoc,      UVM_DEFAULT | UVM_DEC)
    `uvm_object_utils_end

    function new (string name = "");
        super.new(name);
    endfunction

    function void set (uint32_t line_size, uint32_t cache_size, uint32_t assoc);
        this.line_size = line_size;
        this.cache_size = cache_size;
        this.assoc = assoc;
    endfunction
endclass