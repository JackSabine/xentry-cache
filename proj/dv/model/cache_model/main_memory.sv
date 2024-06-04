class main_memory extends memory_element;
    local uint32_t memory [uint32_t];

    function new ();

    endfunction

    local function uint32_t compute_default_value(uint32_t addr);
        uint32_t result;

        result = 0;
        while (addr != 0) begin
            result = (result * 16) + (addr % 16);
            addr = addr / 16;
        end

        return result;
    endfunction

    virtual function uint32_t read(uint32_t addr);
        return memory.exists(addr) ?
            memory[addr] :
            compute_default_value(addr);
    endfunction


    virtual function void write(uint32_t addr, uint32_t data);
        memory[addr] = data;
    endfunction
endclass