class cache_wrapper;
    local cache l1;
    local main_memory memory;

    function new (uint32_t l1_size, uint32_t l1_block_size, uint32_t l1_assoc);
        memory = new;
        l1 = new(l1_size, l1_block_size, l1_assoc, memory);
    endfunction

    function uint32_t read(uint32_t addr);
        l1.read(addr);
    endfunction

    function uint32_t write(uint32_t addr, uint32_t data);
        l1.write(addr, data);
    endfunction

endclass