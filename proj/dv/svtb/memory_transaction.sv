import xentry_types::*;

class memory_transaction extends uvm_sequence_item;

    rand uint32_t                address;
    rand memory_operation_e      op;
    rand memory_operation_size_e size;
    rand uint32_t                data_to_write;
    uint32_t                     data_read;

    constraint operation {
        op != MO_UNKNOWN;
    }

    function new(string name = "");
        super.new(name);
    endfunction

    function string convert2string();
        string s;
        s = $sformatf(
            "addr=%8h | op = %5s | size = %s | data_to_write = %8h | data_read = %8h",
            address, op.name(), size.name(), data_to_write, data_read
        );
        return s;
    endfunction

    `uvm_object_utils_begin(memory_transaction)
        `uvm_field_enum(memory_operation_size_e, size, UVM_ALL_ON)
        `uvm_field_enum(memory_operation_e,      op,   UVM_ALL_ON)
        `uvm_field_int(address,       UVM_ALL_ON | UVM_UNSIGNED)
        `uvm_field_int(data_to_write, UVM_ALL_ON | UVM_UNSIGNED | UVM_NOCOMPARE)
        `uvm_field_int(data_read,     UVM_ALL_ON | UVM_UNSIGNED)
    `uvm_object_utils_end
endclass

class read_only_memory_transaction extends memory_transaction;
    `uvm_object_utils(read_only_memory_transaction)

    constraint read_only_con {
        op inside {LOAD};
    }

    function new(string name = "");
        super.new(name);
    endfunction
endclass
