package xentry_pkg;
    typedef enum logic[1:0] {
        BYTE = 2'b00,
        HALF,
        WORD
    } memory_operation_size_e;

    typedef enum logic {
        STORE = 1'b0,
        LOAD = 1'b1,
        MO_UNKNOWN = 1'bx
    } memory_operation_e;

endpackage: xentry_pkg