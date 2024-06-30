import torrence_types::*;

class memory_transaction extends uvm_sequence_item;

    rand uint32_t                req_address;
    rand memory_operation_e      req_operation;
    rand memory_operation_size_e req_size;
    rand uint32_t                req_store_word;
    rand uint32_t                req_loaded_word;

    time t_issued;
    time t_fulfilled;
    logic expect_hit;

    constraint operation {
        req_operation inside {STORE, LOAD};
    }

    constraint loaded_value_con {
        soft req_loaded_word == 0;
    }

    constraint store_word_con {
        if (req_operation != STORE) {
            req_store_word == '1;
        }
    }

    constraint req_address_granularity_by_req_size {
        if (req_size == WORD) {
            req_address % 4 == 0;
        } else if (req_size == HALF) {
            req_address % 2 == 0;
        } else if (req_size == BYTE) {
            req_address % 1 == 0;
        }

        solve req_size before req_address;
    }

    function new(string name = "");
        super.new(name);
    endfunction

    function string convert2string();
        string s;
        s = $sformatf(
            "addr=%8h | op = %5s | size = %s | store_word = %8h | loaded_word = %8h | t_issued = %5d | t_fulfilled = %5d | expect_hit = %b",
            req_address, req_operation.name(), req_size.name(), req_store_word, req_loaded_word, t_issued, t_fulfilled, expect_hit
        );
        return s;
    endfunction

    `uvm_object_utils_begin(memory_transaction)
        `uvm_field_enum(memory_operation_size_e, req_size,      UVM_ALL_ON)
        `uvm_field_enum(memory_operation_e,      req_operation, UVM_ALL_ON)
        `uvm_field_int(req_address,     UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(req_store_word,  UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(req_loaded_word, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(t_issued,        UVM_ALL_ON | UVM_DEC) // Should be same
        `uvm_field_int(t_fulfilled,     UVM_ALL_ON | UVM_DEC | UVM_NOCOMPARE) // Can be x if scoreboard cannot predict finish time
        `uvm_field_int(expect_hit,      UVM_ALL_ON | UVM_BIN | UVM_NOCOMPARE) // Not populated by monitor
    `uvm_object_utils_end
endclass

class word_memory_transaction extends memory_transaction;
    `uvm_object_utils(word_memory_transaction)

    constraint word_only_con {
        req_size == WORD;
    }

    function new(string name = "");
        super.new(name);
    endfunction
endclass

class icache_transaction extends word_memory_transaction;
    `uvm_object_utils(icache_transaction)

    constraint read_only_con {
        req_operation == LOAD;
    }

    function new(string name = "");
        super.new(name);
    endfunction
endclass

class dcache_transaction extends word_memory_transaction;
    `uvm_object_utils(dcache_transaction)

    function new(string name = "");
        super.new(name);
    endfunction
endclass
