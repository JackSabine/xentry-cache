module dcache_controller import xentry_pkg::*; (
    //// TOP LEVEL ////
    input wire clk,
    input wire reset,

    //// PIPELINE ////
    output logic pipe_req_fulfilled,

    //// HIGHER MEMORY ////
    input wire l2_fetched_word_valid,
    output memory_operation_e l2_req_type,
    output logic l2_req_valid,

    //// DATAPATH/CONTROLLER SIGNALS ////
    input wire counter_done,
    input wire hit,
    input wire dirty_miss,
    input wire clean_miss,

    output logic flush_mode,
    output logic load_mode,
    output logic clear_selected_dirty_bit,
    output logic clear_selected_valid_bit,
    output logic finish_new_line_install,
    output logic set_new_l2_block_address,
    output logic reset_counter,
    output logic decrement_counter
);

typedef enum logic[1:0] {
    ST_IDLE = 2'b00,
    ST_LOAD = 2'b11,
    ST_FLUSH = 2'b10,
    ST_UNKNOWN = 2'bxx
} dcache_state_e;

dcache_state_e state, next_state;

//// NEXT STATE LOGIC ////
always_comb begin
    case (state)
        ST_IDLE: unique casez (1'b1)
            hit:        next_state = ST_IDLE;
            dirty_miss: next_state = ST_FLUSH;
            clean_miss: next_state = ST_LOAD;
            default:    next_state = ST_IDLE;
        endcase

        ST_FLUSH: begin
            if (counter_done) next_state = ST_LOAD;
            else              next_state = ST_FLUSH;
        end

        ST_LOAD: begin
            if (counter_done) next_state = ST_IDLE;
            else              next_state = ST_LOAD;
        end

        default: next_state = ST_UNKNOWN;
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
        ST_IDLE: begin
            if (next_state == ST_FLUSH || next_state == ST_LOAD) begin
                set_new_l2_block_address = 1'b1;
                reset_counter = 1'b1;
            end else begin
                pipe_req_fulfilled = hit;
            end
        end

        ST_FLUSH: begin
            if (next_state == ST_LOAD) begin
                set_new_l2_block_address = 1'b1;
                reset_counter = 1'b1;
                clear_selected_dirty_bit = 1'b1;
                clear_selected_valid_bit = 1'b1;
            end
        end

        ST_LOAD: begin
            if (next_state == ST_IDLE) begin
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
    l2_req_type = LOAD;
    l2_req_valid = 1'b0;

    case (state)
        ST_IDLE: begin

        end

        ST_LOAD: begin
            load_mode = 1'b1;
            l2_req_type = LOAD;
            l2_req_valid = 1'b1;

            if (l2_fetched_word_valid) begin
                decrement_counter = 1'b1;
            end
        end

        ST_FLUSH: begin
            flush_mode = 1'b1;
            l2_req_type = STORE;
            l2_req_valid = 1'b1;

            if (1'b0) begin // FIXME need ack signal from L2
                decrement_counter = 1'b1;
            end
        end

        default: begin
            flush_mode = 1'bx;
            load_mode = 1'bx;
            decrement_counter = 1'bx;
            l2_req_type = MO_UNKNOWN;
            l2_req_valid = 1'bx;
        end
    endcase
end

//// STATE REGISTER ////
always_ff @(posedge clk) begin
    if (reset) begin
        state <= ST_IDLE;
    end else begin
        state <= next_state;
    end
end

endmodule