virtual class memory_element;
    pure virtual function uint32_t read(uint32_t addr);
    pure virtual function void write(uint32_t addr, uint32_t data);
endclass
