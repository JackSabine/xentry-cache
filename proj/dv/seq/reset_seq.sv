class reset_seq extends uvm_sequence #(reset_transaction);
    rand uint32_t reset_duration_in_clocks;
    rand uint32_t post_reset_delay;

    `uvm_object_utils_begin(reset_seq)
        `uvm_field_int(reset_duration_in_clocks, UVM_ALL_ON)
        `uvm_field_int(post_reset_delay,         UVM_ALL_ON)
    `uvm_object_utils_end

    constraint reset_duration_con {
        reset_duration_in_clocks inside {[2:8]};
    }

    constraint post_reset_delay_con {
        post_reset_delay inside {[1:4]};
    }

    function new (string name = "");
        super.new(name);
    endfunction

    task body();
        reset_transaction rst_tx;

        `uvm_info(get_type_name(), $sformatf("%s is starting", get_sequence_path()), UVM_MEDIUM)

        rst_tx = reset_transaction::type_id::create(.name("rst_tx"), .contxt(get_full_name()));
        start_item(rst_tx);
        assert(
            rst_tx.randomize() with {
                reset_duration_in_clocks == local::reset_duration_in_clocks;
                post_reset_delay         == local::post_reset_delay;
            }
        ) else `uvm_fatal(get_full_name(), "Couldn't successfully randomize rst_tx")
        rst_tx.print();
        finish_item(rst_tx);
    endtask
endclass
