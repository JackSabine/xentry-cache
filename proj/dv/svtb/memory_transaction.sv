import xentry_types::*;

class memory_transaction extends uvm_sequence_item;

    rand uint32_t                req_address;
    rand memory_operation_e      req_operation;
    rand memory_operation_size_e req_size;
    rand uint32_t                req_store_word;
    rand uint32_t                req_loaded_word;

    constraint operation {
        req_operation != MO_UNKNOWN;
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
        `uvm_field_int(req_address,     UVM_ALL_ON | UVM_UNSIGNED)
        `uvm_field_int(req_store_word,  UVM_ALL_ON | UVM_UNSIGNED | UVM_NOCOMPARE)
        `uvm_field_int(req_loaded_word, UVM_ALL_ON | UVM_UNSIGNED)
    `uvm_object_utils_end
endclass

class read_only_memory_transaction extends memory_transaction;
    `uvm_object_utils(read_only_memory_transaction)

    constraint read_only_con {
        req_operation inside {LOAD};
    }

    function new(string name = "");
        super.new(name);
    endfunction
endclass
