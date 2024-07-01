import torrence_types::*;

class memory_transaction extends uvm_sequence_item;
    `uvm_object_utils(memory_transaction)

    rand uint32_t                req_address;
    rand memory_operation_e      req_operation;
    rand memory_operation_size_e req_size;
    rand uint32_t                req_store_word;
    rand uint32_t                req_loaded_word;

    time t_issued;
    time t_fulfilled;
    logic expect_hit;

    rand l1_type_e origin;

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

    constraint origin_con {
        soft origin == UNASSIGNED;
    }

    function void post_randomize();
        case (req_size)
        WORD: req_address &= ~32'b11;
        HALF: req_address &= ~32'b01;
        endcase
    endfunction

    function new(string name = "");
        super.new(name);
    endfunction

    function string convert2string();
        string s;
        s = $sformatf(
            "addr=%8h | op = %5s | size = %s | store_word = %8h | loaded_word = %8h | t_issued = %5d | t_fulfilled = %5d | expect_hit = %b | origin = %10s",
            req_address, req_operation.name(), req_size.name(), req_store_word, req_loaded_word, t_issued, t_fulfilled, expect_hit, origin.name()
        );
        return s;
    endfunction

    virtual function void do_copy(uvm_object rhs);
        memory_transaction _obj;
        $cast(_obj, rhs);

        req_address     = _obj.req_address;
        req_operation   = _obj.req_operation;
        req_size        = _obj.req_size;
        req_store_word  = _obj.req_store_word;
        req_loaded_word = _obj.req_loaded_word;
        t_issued        = _obj.t_issued;
        t_fulfilled     = _obj.t_fulfilled;
        expect_hit      = _obj.expect_hit;
        origin          = _obj.origin;
    endfunction

    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        memory_transaction _obj;
        $cast(_obj, rhs);

        // Don't compare t_fulfilled, expect_hit, origin
        return
            req_address     == _obj.req_address     &
            req_operation   == _obj.req_operation   &
            req_size        == _obj.req_size        &
            req_store_word  == _obj.req_store_word  &
            req_loaded_word == _obj.req_loaded_word &
            t_issued        == _obj.t_issued        ;
    endfunction
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

    constraint origin_con {
        origin == ICACHE;
    }

    constraint read_only_con {
        req_operation == LOAD;
    }

    function new(string name = "");
        super.new(name);
    endfunction
endclass

class dcache_transaction extends word_memory_transaction;
    `uvm_object_utils(dcache_transaction)

    constraint origin_con {
        origin == DCACHE;
    }

    function new(string name = "");
        super.new(name);
    endfunction
endclass
