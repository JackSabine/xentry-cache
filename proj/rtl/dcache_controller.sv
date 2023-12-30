module dcache_controller (
    //// TOP LEVEL ////
    input wire clk,
    input wire reset,

    //// DATAPATH/CONTROLLER SIGNALS ////
    input wire counter_done,
    input logic hit,
    input logic dirty_miss,
    input logic clean_miss,

    output logic flush_mode,
    output logic load_mode,
    output logic clear_selected_dirty_bit,
    output logic clear_selected_valid_bit,
    output logic finish_new_line_install,
    output logic set_new_l2_block_address,
    output logic reset_counter,
    output logic decrement_counter,
    output logic l2_access
);

typedef enum logic[1:0] {
    IDLE = 2'b00,
    LOAD = 2'b11,
    FLUSH = 2'b10,
    UNKNOWN = 2'bxx
} dcache_state_e;

dcache_state_e state, next_state;

//// NEXT STATE LOGIC ////
always_comb begin
    case (state)
        IDLE: unique casex (1'b1)
            hit:        next_state = IDLE;
            dirty_miss: next_state = FLUSH;
            clean_miss: next_state = LOAD;
            default:    next_state = IDLE;
        endcase

        FLUSH: begin
            if (counter_done) next_state = LOAD;
            else              next_state = FLUSH;
        end

        LOAD: begin
            if (counter_done) next_state = IDLE;
            else              next_state = LOAD;
        end

        default: next_state = UNKNOWN;
    endcase
end

//// MEALY OUTPUTS ////
always_comb begin
    clear_selected_dirty_bit = 1'b0;
    clear_selected_valid_bit = 1'b0;
    finish_new_line_install = 1'b0;
    set_new_l2_block_address = 1'b0;
    reset_counter = 1'b0;

    case (state)
        IDLE: begin
            if (next_state == FLUSH || next_state == LOAD) begin
                set_new_l2_block_address = 1'b1;
                reset_counter = 1'b1;
            end
        end

        FLUSH: begin
            if (next_state == LOAD) begin
                set_new_l2_block_address = 1'b1;
                reset_counter = 1'b1;
                clear_selected_dirty_bit = 1'b1;
                clear_selected_valid_bit = 1'b1;
            end
        end

        LOAD: begin
            if (next_state == IDLE) begin
                finish_new_line_install = 1'b1;
            end
        end

        default: begin
            clear_selected_dirty_bit = 1'bx;
            clear_selected_valid_bit = 1'bx;
            finish_new_line_install = 1'bx;
            set_new_l2_block_address = 1'bx;
            reset_counter = 1'bx;
        end
    endcase
end

//// MOORE OUTPUTS ////
always_comb begin
    flush_mode = 1'b0;
    load_mode = 1'b0;
    decrement_counter = 1'b0;
    l2_access = 1'b0;

    case (state)
        IDLE: begin

        end

        LOAD: begin
            load_mode = 1'b1;
            decrement_counter = 1'b1;
            l2_access = 1'b1;
        end

        FLUSH: begin
            flush_mode = 1'b1;
            decrement_counter = 1'b1;
            l2_access = 1'b1;
        end

        default: begin
            flush_mode = 1'bx;
            load_mode = 1'bx;
            decrement_counter = 1'bx;
            l2_access = 1'bx;
        end
    endcase
end

//// STATE REGISTER ////
always_ff @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

endmodule