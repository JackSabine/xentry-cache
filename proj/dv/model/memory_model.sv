class memory_model;
    local uint32_t memory [uint32_t];

    local function uint32_t compute_default_value(uint32_t address);
        uint32_t result;

        result = 0;
        while (address != 0) begin
            result = (result * 16) + (address % 16);
            address = address / 16;
        end

        return result;
    endfunction

    function uint32_t read(uint32_t address);
        return memory.exists(address) ?
            memory[address] :
            compute_default_value(address);
    endfunction

    function void write(uint32_t address, uint32_t data);
        memory[address] = data;
    endfunction
endclass
