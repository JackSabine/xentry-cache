virtual class memory_element;
    pure virtual function cache_response_t read(uint32_t addr);
    pure virtual function cache_response_t write(uint32_t addr, uint32_t data);
endclass
