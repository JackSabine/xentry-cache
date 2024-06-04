class cache extends memory_element;
    memory_element lower_memory;

    local cache_set sets[];

    local const uint8_t num_set_bits;
    local const uint8_t num_tag_bits;
    local const uint8_t num_offset_bits;

    local const uint8_t words_per_block;

    function new (uint32_t cache_size, uint32_t block_size, uint8_t associativity, memory_element lower_memory);
        uint32_t num_sets;

        num_sets = cache_size / (block_size * associativity);

        this.lower_memory = lower_memory;
        this.num_set_bits = $clog2(num_sets);
        this.num_offset_bits = $clog2(block_size);
        this.num_tag_bits = 32 - (this.num_set_bits + this.num_offset_bits);

        this.words_per_block = block_size / 4;

        this.sets = new [num_sets];
    endfunction

    local function uint32_t get_set(uint32_t addr);
        uint32_t mask;

        mask = (1 << num_set_bits) - 1;
        return (addr >> this.num_offset_bits) & mask;
    endfunction

    local function uint32_t get_tag(uint32_t addr);
        return addr >> (this.num_offset_bits + this.num_set_bits);
    endfunction

    local function uint32_t get_ofs(uint32_t addr);
        uint32_t mask;

        mask = (1 << num_offset_bits) - 1;
        return addr & mask;
    endfunction

    local function uint32_t construct_addr(uint32_t tag, uint32_t set, uint32_t ofs);
        uint32_t addr;

        addr = 0;
        addr = (addr | tag) << num_set_bits;
        addr = (addr | set) << num_offset_bits;
        addr = (addr | ofs);
        return addr; 
    endfunction

    // Cache miss recovery
    //  1. Handles writebacks if needed, then evict the victim
    //  2. Fetch data from lower memory
    //  3. Install fetched block
    //
    local function void handle_miss(uint32_t tag, uint32_t set);
        if (this.sets[set].is_victim_dirty()) begin
            for (int i = 0; i < this.words_per_block; i++) begin
                this.lower_memory.write(
                    this.construct_addr(this.sets[set].get_victim_tag(), set, i),
                    this.sets[set].get_indexed_victim_word(i)
                );
            end

            this.sets[set].evict_victim();
        end

        for (int i = 0; i < this.words_per_block; i++) begin
            this.sets[set].set_indexed_victim_word(
                i,
                this.lower_memory.read(
                    this.construct_addr(tag, set, 4*i)
                )
            );
        end

        this.sets[set].install(tag);

        assert(this.sets[set].is_cached(tag)) else $fatal(1, "cache::handle_miss() did not correctly install the block");
    endfunction

    // Top-level cache read
    // 1. a. Search corresponding cache set for addr
    //    b. If missed, handle it
    // 2. Perform the read and return the word
    //
    virtual function uint32_t read(uint32_t addr);
        bit cache_hit;
        uint32_t set, tag, ofs;

        set = get_set(addr);
        tag = get_tag(addr);
        ofs = get_ofs(addr);

        cache_hit = this.sets[set].is_cached(tag);

        if (!cache_hit) begin
            this.handle_miss(tag, set);
        end

        return this.sets[set].read_word(tag, ofs);
    endfunction

    // Top-level cache write
    // 1. a. Search corresponding cache set for addr
    //    b. If missed, handle it
    // 2. Perform the write
    //
    virtual function void write(uint32_t addr, uint32_t data);
        bit cache_hit;
        uint32_t set, tag, ofs;

        set = get_set(addr);
        tag = get_tag(addr);
        ofs = get_ofs(addr);

        cache_hit = this.sets[set].is_cached(tag);

        if (!cache_hit) begin
            this.handle_miss(tag, set);
        end

        this.sets[set].write_word(tag, ofs, data);
    endfunction
endclass