class clock_config extends uvm_object;
    rand uint32_t t_period;
    rand uint32_t duty_cycle;

    real frequency;
    real t_high;
    real t_low;

    constraint period_con {
        t_period inside {[1:100]};
    }

    constraint dc_con {
        duty_cycle inside {[20:80]};
    }

    function string convert2string();
        return $sformatf("freq = %F MHz | dc = %0D | T = %F ns | t_high = %F ns | t_low = %F ns", real'(frequency) / 1e6, duty_cycle, t_period, t_high, t_low);
    endfunction

    function void post_randomize();
        // In nanoseconds
        // Period is a whole number, so whole number duty cycle %'s will leave a minimum resolution of 10 ps
        // E.g. t_period * duty_cycle ==> 1 [ns] * (0.01 * 1) = 0.01 [ns] = 10.0 [ps]
        t_high = t_period * (0.01 * this.duty_cycle);
        t_low = t_period - t_high;

        frequency = 1.0 / (t_period * 1e-9);
    endfunction

    `uvm_object_utils_begin(clock_config)
        `uvm_field_real(frequency, UVM_DEFAULT)
        `uvm_field_int(t_period,   UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(duty_cycle, UVM_DEFAULT | UVM_DEC)
    `uvm_object_utils_end

    function new (string name = "");
        super.new(name);
    endfunction
endclass
