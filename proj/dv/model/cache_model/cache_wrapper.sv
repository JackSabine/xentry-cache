class cache_wrapper;
    local cache icache, dcache;
    local main_memory memory;

    function new (uint32_t l1_size, uint32_t l1_block_size, uint32_t l1_assoc);
        memory = new;
        icache = new(l1_size, l1_block_size, l1_assoc, memory);
        dcache = new(l1_size, l1_block_size, l1_assoc, memory);
    endfunction

    local function uint32_t gen_bitmask(uint8_t width);
        return (1 << width) - 1;
    endfunction

    local function uint32_t select_read_data(uint32_t read_data, memory_operation_size_e op_size, uint8_t byte_offset);
        uint32_t mask;

        unique case (op_size)
            BYTE: mask = gen_bitmask(8);
            HALF: mask = gen_bitmask(16);
            WORD: mask = gen_bitmask(32);
        endcase

        return mask & (read_data >> (8 * byte_offset));
    endfunction

    local function uint32_t insert_write_data(uint32_t read_data, uint32_t write_data, memory_operation_size_e op_size, uint8_t byte_offset);
        uint32_t mask;

        unique case (op_size)
            BYTE: mask = gen_bitmask(8);
            HALF: mask = gen_bitmask(16);
            WORD: mask = gen_bitmask(32);
        endcase

        write_data &= mask;

        mask <<= (8 * byte_offset);
        write_data <<= (8 * byte_offset);

        read_data &= ~mask;
        read_data |= write_data;

        return read_data;
    endfunction

    function cache_response_t read(uint32_t addr, l1_type_e cache_type);
        cache_response_t resp;

        case (cache_type)
            ICACHE: resp = icache.read(addr);
            DCACHE: resp = dcache.read(addr);
            default: `uvm_fatal("cache_wrapper::read", $sformatf("unimplemented cache_type %s", cache_type.name()))
        endcase

        `uvm_info("cache_wrapper", $sformatf("l1.read(%8H) returned %8H (hit = %B)", addr, resp.req_word, resp.is_hit), UVM_HIGH)
        resp.req_word = select_read_data(resp.req_word, WORD, 0);
        return resp;
    endfunction

    function cache_response_t write(uint32_t addr, uint32_t data, l1_type_e cache_type);
        cache_response_t read_resp, write_resp;
        uint32_t read_data, data_to_write;

        case (cache_type)
            ICACHE: read_resp = icache.read(addr);
            DCACHE: read_resp = dcache.read(addr);
            default: `uvm_fatal("cache_wrapper::write", $sformatf("unimplemented cache_type %s", cache_type.name()))
        endcase

        data_to_write = insert_write_data(read_resp.req_word, data, WORD, 0);

        case (cache_type)
            ICACHE: write_resp = icache.write(addr, data_to_write);
            DCACHE: write_resp = dcache.write(addr, data_to_write);
            default: `uvm_fatal("cache_wrapper::write", $sformatf("unimplemented cache_type %s", cache_type.name()))
        endcase

        write_resp.is_hit = read_resp.is_hit; // write_resp will always hit because we already read, so check read_resp instead

        return write_resp;
    endfunction

endclass