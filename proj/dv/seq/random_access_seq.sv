class random_access_seq extends uvm_sequence #(memory_transaction);
    rand uint32_t num_blocks_to_access;
    rand uint32_t accesses_per_block;

    rand uint32_t block_array[];

    cache_config dut_config;

    uint32_t block_mask, offset_mask;

    `uvm_object_utils_begin(random_access_seq)
        `uvm_field_int(num_blocks_to_access, UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(accesses_per_block,   UVM_ALL_ON | UVM_DEC)
        `uvm_field_array_int(block_array,    UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(block_mask,           UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(offset_mask,          UVM_ALL_ON | UVM_HEX)
    `uvm_object_utils_end

    constraint blocks_con {
        soft num_blocks_to_access inside {[20:40]};
        accesses_per_block == 8;

        block_array.size() == num_blocks_to_access;
        // unique {block_array}; -- unsupported in Vivado 2022.2
    }

    function new(string name = "");
        super.new(name);
        generate_block_mask_and_offset_mask();
    endfunction

    function void generate_block_mask_and_offset_mask();
        uint32_t mask;
        cache_config dut_config;

        assert(uvm_config_db #(cache_config)::get(
            .cntxt(null),
            .inst_name("*"),
            .field_name("cache_config"),
            .value(dut_config)
        )) else `uvm_fatal(get_full_name(), "Couldn't get cache_config from config db")

        mask = $clog2(dut_config.line_size); // block_size = 32 --> 5
        mask = (1 << mask);                  // (1 << 5) --> 00100000
        mask = (mask - 1);                   // (00100000 - 1) --> 00011111 (five 1's)

        offset_mask = mask;
        block_mask = ~mask;                  // (~00011111) --> 11100000
    endfunction

    function void post_randomize();
        foreach (block_array[i]) begin
            block_array[i] &= block_mask;
        end
    endfunction

    task body();
        uint32_t block;

        `uvm_info(get_type_name(), $sformatf("%s is starting", get_sequence_path()), UVM_MEDIUM)

        repeat (num_blocks_to_access) begin
            assert(std::randomize(block) with { block inside {block_array}; }) else `uvm_fatal(get_full_name(), "Couldn't randomize block")

            repeat(accesses_per_block) begin
                `uvm_do_with(req, { req_address inside {[block : block+offset_mask]}; })
            end
        end
    endtask
endclass
