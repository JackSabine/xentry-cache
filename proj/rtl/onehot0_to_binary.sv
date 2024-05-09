module onehot0_to_binary #(
    parameter ONEHOT_WIDTH = 32,
    parameter BINARY_WIDTH = $clog2(ONEHOT_WIDTH)
) (
    input wire [ONEHOT_WIDTH-1:0] onehot0,
    output logic [BINARY_WIDTH-1:0] binary
);

always_comb begin
    int stride;
    int group_size;
    int init;

    int j;
    int group_count;

    for (int i = 0; i < BINARY_WIDTH; i++) begin
        stride = (2 ** i) + 1;
        group_size = (2 ** i);
        init = (2 ** i);

        j = init;
        group_count = 0;

        binary[i] = 1'b0;

        while (j < ONEHOT_WIDTH) begin
            binary[i] = binary[i] | onehot0[j];
            group_count++;

            if (group_count == group_size) begin
                j = j + stride;
            end else begin
                j++;
            end
        end
    end
end

endmodule