class cache_model;
    typedef struct packed {
        bit dirty;
        bit valid;
        uint32_t tag;
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
            this.sets[i].tag = '0;
        end
    endfunction

    function uint32_t get_set(uint32_t address);
        uint32_t mask;

        mask = (1 << set_bits) - 1;
        return (address >> this.offset_bits) & mask;
    endfunction

    function uint32_t get_tag(uint32_t address);
        return address >> (this.offset_bits + this.set_bits);
    endfunction

    function bit is_cached(uint32_t address);
        uint32_t s, t;

        s = get_set(address);
        t = get_tag(address);

        return (sets[s].valid) && (sets[s].tag == t);
    endfunction

    function bit assert_is_cached(uint32_t address);
        if (!is_cached(address)) begin
            `uvm_error("cache_model", $sformatf("assert_is_cached(%08x) failed", address))
        end

        return is_cached(address);
    endfunction

    function bit assert_is_not_cached(uint32_t address);
        if (is_cached(address)) begin
            `uvm_error("cache_model", $sformatf("assert_is_not_cached(%08x) failed", address))
        end

        return !is_cached(address);
    endfunction

    function bit is_dirty(uint32_t address);
        uint32_t s;

        s = get_set(address);

        return assert_is_cached(address) && sets[s].dirty;
    endfunction

    function void clear_dirty(uint32_t address);
        uint32_t s;

        s = get_set(address);

        if (assert_is_cached(address)) begin
            sets[s].dirty = 1'b0;
        end
    endfunction

    function void set_dirty(uint32_t address);
        uint32_t s;

        s = get_set(address);

        if (assert_is_cached(address)) begin
            sets[s].dirty = 1'b1;
        end
    endfunction

    function void install(uint32_t address);
        uint32_t s, t;

        s = get_set(address);
        t = get_tag(address);

        if (assert_is_not_cached(address)) begin
            sets[s].valid = 1'b1;
            sets[s].dirty = 1'b0;
            sets[s].tag = t;
        end
    endfunction

    function void evict(uint32_t address);
        uint32_t s;

        s = get_set(address);

        // Block may not be present, but if it is, it cannot be dirty
        if (is_cached(address)) begin
            if(is_dirty(address)) begin
                `uvm_error("cache_model", "evict(%08x) called on cached dirty block", address)
            end else begin
                sets[s].valid = 1'b0;
                sets[s].tag = 0;
            end
        end
    endfunction
endclass
