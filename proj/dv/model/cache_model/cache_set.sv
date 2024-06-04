class cache_set;
    typedef struct {
        uint32_t data[];
        bit dirty;
        bit valid;
        uint32_t tag;
        uint32_t recency;
    } cache_block_t;

    local cache_block_t blocks[];
    local uint32_t words_per_block;

    function new (uint8_t associativity, uint32_t words_per_block);
        this.blocks = new [associativity];
        foreach (this.blocks[i]) begin
            this.blocks[i].data = new [words_per_block];
            this.blocks[i].dirty = 1'b0;
            this.blocks[i].valid = 1'b0;
            this.blocks[i].tag = 0;
            this.blocks[i].recency = i;
        end

        this.words_per_block = words_per_block;
    endfunction

    local function uint8_t get_victim_way();
        foreach (this.blocks[i]) begin
            if (this.blocks[i].recency == '1) begin
                return i;
            end
        end

        $fatal("No victim had maximum recency counter");
    endfunction

    local function uint8_t get_hit_way(uint32_t tag);
        foreach (this.blocks[i]) begin
            if (this.blocks[i].tag == tag) begin
                return i;
            end
        end

        $fatal("get_hit_way:: No way matched requested tag");
    endfunction

    function bit is_victim_dirty();
        uint8_t victim_way;

        victim_way = this.get_victim_way();
        return this.blocks[victim_way].valid & this.blocks[victim_way].dirty;
    endfunction

    function uint32_t get_victim_tag();
        uint8_t victim_way;

        victim_way = this.get_victim_way();
        return this.blocks[victim_way].tag;
    endfunction

    function uint32_t get_indexed_victim_word(uint32_t offset);
        uint8_t victim_way;

        victim_way = this.get_victim_way();
        return this.blocks[victim_way].data[offset];
    endfunction

    function void set_indexed_victim_word(uint32_t offset, uint32_t data);
        uint8_t victim_way;

        victim_way = this.get_victim_way();
        this.blocks[victim_way].data[offset] = data;
    endfunction

    function void evict_victim();
        uint8_t victim_way;

        victim_way = this.get_victim_way();
        this.blocks[victim_way].dirty = 1'b0;
        this.blocks[victim_way].valid = 1'b0;
    endfunction

    function void install(uint32_t tag);
        uint8_t victim_way;

        victim_way = this.get_victim_way();
        this.blocks[victim_way].tag = tag;
        this.blocks[victim_way].valid = 1'b0;
    endfunction

    function bit is_cached(uint32_t tag);
        foreach (this.blocks[i]) begin
            if (this.blocks[i].valid && this.blocks[i].tag == tag) return 1'b1;
        end

        return 1'b0;
    endfunction

    local function void update_recency_counters(uint8_t hit_way);
        foreach (this.blocks[i]) begin
            if (this.blocks[i].recency < this.blocks[hit_way].recency) begin
                this.blocks[i].recency++;
            end
        end

        this.blocks[hit_way].recency = 0;
    endfunction

    function uint32_t read_word(uint32_t tag, uint32_t ofs);
        uint8_t hit_way;
        uint32_t word_index;

        hit_way = get_hit_way(tag);

        update_recency_counters(hit_way);

        word_index = ofs / 4;

        return this.blocks[hit_way].data[word_index];
    endfunction

    function void write_word(uint32_t tag, uint32_t ofs, uint32_t data);
        uint8_t hit_way;
        uint32_t word_index;

        hit_way = get_hit_way(tag);

        update_recency_counters(hit_way);

        word_index = ofs / 4;

        this.blocks[hit_way].data[word_index] = data;
    endfunction
endclass