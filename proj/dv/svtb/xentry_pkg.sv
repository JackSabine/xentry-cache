package xentry_pkg;
    typedef enum logic[1:0] {
        BYTE = 2'b00,
        HALF,
        WORD
    } memory_operation_size_e;

    typedef enum logic [1:0] {
        STORE = 2'b00,
        LOAD = 2'b01,
        CLFLUSH = 2'b11,
        MO_UNKNOWN = 2'bxx
    } memory_operation_e;

endpackage: xentry_pkg