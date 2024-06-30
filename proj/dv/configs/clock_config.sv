class clock_config extends uvm_object;
    rand uint32_t t_period;
    uint32_t t_half_period;

    real frequency;

    constraint period_con {
        t_period inside {[2:10]};
        t_period % 2 == 0;
    }

    function string convert2string();
        return $sformatf("freq = %F MHz | T = %F ns", (frequency / 1e6), t_period);
    endfunction

    function void post_randomize();
        t_half_period = t_period / 2;
        frequency = 1.0 / (t_period * 1e-9);
    endfunction

    `uvm_object_utils_begin(clock_config)
        `uvm_field_real(frequency,    UVM_DEFAULT)
        `uvm_field_int(t_period,      UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(t_half_period, UVM_DEFAULT | UVM_DEC)
    `uvm_object_utils_end

    function new (string name = "");
        super.new(name);
    endfunction
endclass
