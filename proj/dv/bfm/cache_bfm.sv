class cache_bfm;
    typedef struct packed {
        bit dirty;
        bit valid;
        uint32_t block_address;
    } cacheline_t;

    uint32_t num_sets;
    uint32_t set_bits;
    uint32_t offset_bits;

    cacheline_t sets[];

    function new(uint32_t cache_size, uint32_t cacheline_size, uint32_t offset_bits);
        this.num_sets = cache_size / cacheline_size;
        this.set_bits = $clog2(num_sets);
        this.offset_bits = offset_bits;

        this.sets = new [num_sets];

        foreach (sets[i]) begin
            this.sets[i].valid = 1'b0;
            this.sets[i].dirty = 1'b0;
            this.sets[i].block_address = 0;
        end
    endfunction

    function uint32_t get_set_from_block_address(uint32_t block_address);
        uint32_t mask;

        mask = (1 << set_bits) - 1;
        return (block_address >> this.offset_bits) & mask;
    endfunction

    function bit is_cached(uint32_t block_address);
        uint32_t s;

        s = get_set_from_block_address(block_address);

        return (sets[s].valid) && (sets[s].block_address == block_address);
    endfunction

    function bit is_dirty(uint32_t block_address);
        uint32_t s;

        s = get_set_from_block_address(block_address);

        return is_cached(block_address) && sets[s].dirty;
    endfunction

    function void clear_dirty(uint32_t block_address);
        uint32_t s;

        s = get_set_from_block_address(block_address);

        if (is_cached(block_address)) begin
            sets[s].dirty = 1'b0;
        end
    endfunction

    function void write_to_block(uint32_t block_address);
        uint32_t s;

        s = get_set_from_block_address(block_address);

        assert(is_cached(block_address)) else $error("write_to_block(%08x) called on uncached block", block_address);

        sets[s].dirty = 1'b1;
    endfunction

    function void install_block(uint32_t block_address);
        uint32_t s;

        s = get_set_from_block_address(block_address);

        sets[s].valid = 1'b1;
        sets[s].dirty = 1'b0;
        sets[s].block_address = block_address;
    endfunction

    function void evict_block(uint32_t block_address);
        uint32_t s;

        s = get_set_from_block_address(block_address);

        // Block may not be present, but if it is, it cannot be dirty
        assert(!is_dirty(block_address)) else $error("evict_block(%08x) called on cached dirty block", block_address);

        if (is_cached(block_address) && !is_dirty(block_address)) begin
            sets[s].valid = 1'b0;
            sets[s].block_address = 0;
        end
    endfunction
endclass
