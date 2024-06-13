class trace_based_memory_seq extends uvm_sequence #(memory_transaction);
    rand uint32_t num_transactions;
    rand uint8_t file_index;
    rand uint32_t num_trace_lines_to_skip;

    string file_name;

    const static uint32_t FILE_LENGTH = 100000;

    static string fname_table[] = '{
        "compress", "gcc", "go", "perl", "vortex"
    };

    `uvm_object_utils_begin(trace_based_memory_seq)
        `uvm_field_int(num_transactions,        UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(num_trace_lines_to_skip, UVM_ALL_ON | UVM_DEC)
        `uvm_field_string(file_name,            UVM_ALL_ON)
    `uvm_object_utils_end

    constraint num_transactions_con {
        num_transactions      inside {[1:FILE_LENGTH]};
        soft num_transactions inside {[64:128]};

        num_trace_lines_to_skip + num_transactions <= FILE_LENGTH;

        solve num_transactions before num_trace_lines_to_skip;
    }

    constraint file_index_con {
        file_index inside {[0:fname_table.size()-1]};
    }

    function void post_randomize();
        file_name = {get_environment_variable("DV_MODELS"), "/cache_model/traces/", file_index_to_file_name(file_index), "_trace.txt"};
    endfunction

    local function string file_index_to_file_name(uint8_t index);
        if (index > fname_table.size()) index = 0;

        return fname_table[index];
    endfunction

    function new (string name = "");
        super.new(name);
    endfunction

    task body();
        memory_transaction mem_tx;
        uint32_t i, address;
        int fd, rd_code;
        string tmp;

        `uvm_info(get_type_name(), $sformatf("%s is starting", get_sequence_path()), UVM_MEDIUM)

        fd = $fopen(file_name, "r");

        if (!fd) begin
            `uvm_error(get_type_name(), {"Could not open file ", file_name, ". Terminating sequence."})
            return;
        end

        repeat(num_trace_lines_to_skip) begin
            if ($feof(fd)) break;
            $fgets(tmp, fd);
        end

        i = 0;
        while (i++ < num_transactions && !$feof(fd)) begin
            rd_code = $fscanf(fd, "%x\n", address);

            if (rd_code == 1) begin
                mem_tx = memory_transaction::type_id::create(.name("mem_tx"), .contxt(get_full_name()));
                start_item(mem_tx);
                assert(
                    mem_tx.randomize() with {
                        mem_tx.req_address == address;
                    }
                ) else `uvm_fatal(get_type_name(), "Couldn't successfully randomize mem_tx")
                `uvm_info(get_type_name(), $sformatf("Address transaction #%0d from line %0d:\n%s", i, i + num_trace_lines_to_skip, mem_tx.sprint()), UVM_MEDIUM)
                finish_item(mem_tx);
            end else if (rd_code == -1) begin
                `uvm_error(get_type_name(), $sformatf("Incorrectly formatted line or $fscanf error on line %d", i))
            end
        end

        $fclose(fd);
    endtask
endclass
