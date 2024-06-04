class reset_driver extends uvm_driver #(reset_transaction);
    `uvm_component_utils(reset_driver)

    virtual reset_if rst_vi;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        assert(uvm_config_db #(virtual reset_if)::get(
            .cntxt(this),
            .inst_name(""),
            .field_name("reset_if"),
            .value(rst_vi)
        )) else `uvm_fatal(get_full_name(), "Couldn't get reset_if from config db")
    endfunction

    task run_phase(uvm_phase phase);
        reset_transaction rst_tx;

        forever begin
            seq_item_port.get_next_item(rst_tx);

            `uvm_info(
                get_full_name(),
                $sformatf(
                    "Driving txn: %s",
                    rst_tx.convert2string()
                ),
                UVM_DEBUG
            )

            rst_vi.reset <= 1'b1;
            repeat(rst_tx.reset_duration_in_clocks) @(posedge rst_vi.clk);

            rst_vi.reset <= 1'b0;
            repeat(rst_tx.post_reset_delay) @(posedge rst_vi.clk);
            seq_item_port.item_done();
        end
   endtask
endclass
