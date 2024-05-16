module icache_controller import torrence_types::*; (
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

    output logic load_mode,
    output logic perform_write,
    output logic clear_selected_valid_bit,
    output logic finish_new_line_install,
    output logic set_new_l2_block_address,
    output logic reset_counter,
    output logic decrement_counter
);

typedef enum logic[1:0] {
    ST_IDLE = 2'b00,
    ST_ALLOCATE = 2'b11,
    ST_UNKNOWN = 2'bxx
} icache_state_e;

icache_state_e state, next_state;

//// NEXT STATE LOGIC AND MEALY OUTPUTS ////
always_comb begin
    {
        perform_write,
        clear_selected_valid_bit,
        finish_new_line_install,
        set_new_l2_block_address,
        reset_counter,
        pipe_req_fulfilled,
        decrement_counter
    } = '0;

    case (state)
        ST_IDLE: begin
            if (pipe_req_valid) begin
                if (pipe_req_type == CLFLUSH) begin
                    unique casez ({valid_block_match})
                        1'b0: begin : clflush_block_not_present
                            next_state = ST_IDLE;
                            pipe_req_fulfilled = 1'b1;
                        end
                        1'b1: begin : clflush_block_present_and_clean
                            next_state = ST_IDLE;
                            clear_selected_valid_bit = 1'b1;
                            pipe_req_fulfilled = 1'b1;
                        end
                    endcase
                end else begin
                    unique casez ({valid_block_match})
                        1'b0: begin : clean_miss
                            next_state = ST_ALLOCATE;
                            set_new_l2_block_address = 1'b1;
                            reset_counter = 1'b1;
                        end
                        1'b1: begin : hit
                            next_state = ST_IDLE;
                            pipe_req_fulfilled = 1'b1;
                            // STOREs are treated as if they were LOADs
                            // No dirty bits are set
                        end
                    endcase
                end
            end else begin
                next_state = ST_IDLE;
            end
        end

        ST_ALLOCATE: begin
            if (l2_req_fulfilled) begin
                perform_write = 1'b1;
                decrement_counter = 1'b1;
            end

            if (counter_done) begin
                next_state = ST_IDLE;
                finish_new_line_install = 1'b1;
            end else begin
                next_state = ST_ALLOCATE;
            end
        end

        default: begin
            next_state = ST_UNKNOWN;
            {
                perform_write,
                clear_selected_valid_bit,
                finish_new_line_install,
                set_new_l2_block_address,
                reset_counter,
                pipe_req_fulfilled,
                decrement_counter
            } = 'x;
        end
    endcase
end

//// MOORE OUTPUTS ////
always_comb begin
    load_mode = 1'b0;
    l2_req_type = LOAD;
    l2_req_valid = 1'b0;

    case (state) inside
        ST_IDLE: begin

        end

        ST_ALLOCATE: begin
            load_mode = 1'b1;
            l2_req_type = LOAD;
            l2_req_valid = 1'b1;
        end

        default: begin
            load_mode = 1'bx;
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