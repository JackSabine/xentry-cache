import torrence_types::*;

class memory_transaction extends uvm_sequence_item;

    rand uint32_t                req_address;
    rand memory_operation_e      req_operation;
    rand memory_operation_size_e req_size;
    rand uint32_t                req_store_word;
    rand uint32_t                req_loaded_word;

    constraint operation {
        req_operation != MO_UNKNOWN;
    }

    constraint loaded_value_con {
        soft req_loaded_word == 0;
    }

    constraint req_address_granularity_by_req_size {
        if (req_size == WORD) {
            req_address % 4 == 0;
        } else if (req_size == HALF) {
            req_address % 2 == 0;
        } else if (req_size == BYTE) {
            req_address % 1 == 0;
        }
    }

    function new(string name = "");
        super.new(name);
    endfunction

    function string convert2string();
        string s;
        s = $sformatf(
            "addr=%8h | op = %5s | size = %s | store_word = %8h | loaded_word = %8h",
            req_address, req_operation.name(), req_size.name(), req_store_word, req_loaded_word
        );
        return s;
    endfunction

    `uvm_object_utils_begin(memory_transaction)
        `uvm_field_enum(memory_operation_size_e, req_size,      UVM_ALL_ON)
        `uvm_field_enum(memory_operation_e,      req_operation, UVM_ALL_ON)
        `uvm_field_int(req_address,     UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(req_store_word,  UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(req_loaded_word, UVM_ALL_ON | UVM_HEX)
    `uvm_object_utils_end
endclass

class read_only_memory_transaction extends memory_transaction;
    `uvm_object_utils(read_only_memory_transaction)

    constraint read_only_con {
        req_operation inside {LOAD};
        req_store_word == '1;
    }

    function new(string name = "");
        super.new(name);
    endfunction
endclass

class icache_read_only_memory_transaction extends read_only_memory_transaction;
    `uvm_object_utils(icache_read_only_memory_transaction)

    constraint word_only_con {
        req_size == WORD;
    }

    function new(string name = "");
        super.new(name);
    endfunction
endclass

class read_and_flush_memory_transaction extends memory_transaction;
    `uvm_object_utils(read_and_flush_memory_transaction)

    constraint read_only_con {
        req_operation dist {
            LOAD    := 90,
            CLFLUSH := 10
        };
        req_store_word == '1;
    }

    function new(string name = "");
        super.new(name);
    endfunction
endclass

class icache_memory_transaction extends read_and_flush_memory_transaction;
    `uvm_object_utils(icache_memory_transaction)

    constraint word_only_con {
        req_size == WORD;
    }

    function new(string name = "");
        super.new(name);
    endfunction
endclass

