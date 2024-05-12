module dcache_controller import xentry_types::*; (
    //// TOP LEVEL ////
    input wire clk,
    input wire reset,

    //// PIPELINE ////
    input wire pipe_req_valid,
    input wire memory_operation_e pipe_req_type,
    output logic pipe_req_fulfilled,

    //// HIGHER MEMORY ////
    input wire l2_req_fulfilled,
    output memory_operation_e l2_req_type,
    output logic l2_req_valid,

    //// DATAPATH/CONTROLLER SIGNALS ////
    input wire counter_done,
    input wire valid_block_match,
    input wire valid_dirty_bit,

    output logic flush_mode,
    output logic load_mode,
    output logic clear_selected_dirty_bit,
    output logic set_selected_dirty_bit,
    output wire perform_write,
    output logic clear_selected_valid_bit,
    output logic finish_new_line_install,
    output logic set_new_l2_block_address,
    output logic use_dirty_tag_for_l2_block_address,
    output logic reset_counter,
    output logic decrement_counter
);

typedef enum logic[1:0] {
    ST_IDLE = 2'b00,
    ST_FLUSH = 2'b01,
    ST_ALLOCATE = 2'b11,
    ST_WRITEBACK = 2'b10,
    ST_UNKNOWN = 2'bxx
} dcache_state_e;

dcache_state_e state, next_state;

logic mealy_perform_write, moore_perform_write;

assign perform_write = mealy_perform_write | moore_perform_write;

//// NEXT STATE LOGIC AND MEALY OUTPUTS ////
always_comb begin
    {
        clear_selected_dirty_bit,
        set_selected_dirty_bit,
        mealy_perform_write,
        clear_selected_valid_bit,
        finish_new_line_install,
        set_new_l2_block_address,
        use_dirty_tag_for_l2_block_address,
        reset_counter,
        pipe_req_fulfilled
    } = '0;

    case (state)
        ST_IDLE: begin
            if (pipe_req_valid) begin
                if (pipe_req_type == CLFLUSH) begin
                    unique casez ({valid_block_match, valid_dirty_bit})
                        2'b0?: begin : clflush_block_not_present
                            next_state = ST_IDLE;
                            pipe_req_fulfilled = 1'b1;
                        end
                        2'b10: begin : clflush_block_present_and_clean
                            next_state = ST_IDLE;
                            clear_selected_valid_bit = 1'b1;
                            pipe_req_fulfilled = 1'b1;
                        end
                        2'b11: begin : clflush_block_present_and_dirty
                            next_state = ST_FLUSH;
                            use_dirty_tag_for_l2_block_address = 1'b1;
                            set_new_l2_block_address = 1'b1;
                            reset_counter = 1'b1;
                        end
                    endcase
                end else begin
                    unique casez ({valid_block_match, valid_dirty_bit})
                        2'b00: begin : clean_miss
                            next_state = ST_ALLOCATE;
                            set_new_l2_block_address = 1'b1;
                            reset_counter = 1'b1;
                        end
                        2'b1?: begin : hit
                            next_state = ST_IDLE;
                            pipe_req_fulfilled = 1'b1;
                            if (pipe_req_type == STORE) begin
                                mealy_perform_write = 1'b1;
                                set_selected_dirty_bit = 1'b1;
                            end
                        end
                        2'b01: begin : dirty_miss
                            next_state = ST_WRITEBACK;
                            use_dirty_tag_for_l2_block_address = 1'b1;
                            set_new_l2_block_address = 1'b1;
                            reset_counter = 1'b1;
                        end
                    endcase
                end
            end else begin
                next_state = ST_IDLE;
            end
        end

        ST_WRITEBACK: begin
            if (counter_done) begin
                next_state = ST_ALLOCATE;
                set_new_l2_block_address = 1'b1;
                reset_counter = 1'b1;
                clear_selected_dirty_bit = 1'b1;
                clear_selected_valid_bit = 1'b1;
            end else begin
                next_state = ST_WRITEBACK;
            end
        end

        ST_ALLOCATE: begin
            if (counter_done) begin
                next_state = ST_IDLE;
                finish_new_line_install = 1'b1;
                clear_selected_dirty_bit = 1'b1;
            end else begin
                next_state = ST_ALLOCATE;
            end
        end

        ST_FLUSH: begin
            if (counter_done) begin
                next_state = ST_IDLE;
                clear_selected_dirty_bit = 1'b1;
                clear_selected_valid_bit = 1'b1;
                pipe_req_fulfilled = 1'b1;
            end else begin
                next_state = ST_FLUSH;
            end
        end

        default: begin
            next_state = ST_UNKNOWN;
            {
                clear_selected_dirty_bit,
                set_selected_dirty_bit,
                mealy_perform_write,
                clear_selected_valid_bit,
                finish_new_line_install,
                set_new_l2_block_address,
                use_dirty_tag_for_l2_block_address,
                reset_counter,
                pipe_req_fulfilled
            } = 'x;
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
    moore_perform_write = 1'b0;

    case (state) inside
        ST_IDLE: begin

        end

        ST_ALLOCATE: begin
            load_mode = 1'b1;
            l2_req_type = LOAD;
            l2_req_valid = 1'b1;
            moore_perform_write = 1'b1;

            if (l2_req_fulfilled) begin
                decrement_counter = 1'b1;
            end
        end

        ST_FLUSH, ST_WRITEBACK: begin
            flush_mode = 1'b1;
            l2_req_type = STORE;
            l2_req_valid = 1'b1;

            if (l2_req_fulfilled) begin
                decrement_counter = 1'b1;
            end
        end

        default: begin
            flush_mode = 1'bx;
            load_mode = 1'bx;
            decrement_counter = 1'bx;
            l2_req_type = MO_UNKNOWN;
            l2_req_valid = 1'bx;
            moore_perform_write = 1'bx;
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