`timescale 1ns/1ps

module URP_PCIE_TOP_tb;
    // Clock and reset signals
    reg clk;
    reg rst_n;

    // Input signals
    reg [127:0] payload_i;
    reg [29:0]  addr_i;
    reg [2:0]   header_fmt_i;
    reg [4:0]   header_type_i;
    reg [2:0]   header_tc_i;
    reg [8:0]   header_length_i;
    reg [3:0]   header_tagID_i;
    reg [15:0]  header_requestID_i;
    reg [15:0]  header_completID_i;

    // Output signals
    wire [127:0] payload_o;
    wire [29:0]  addr_o;
    wire [2:0]   header_fmt_o;
    wire [4:0]   header_type_o;
    wire [2:0]   header_tc_o;
    wire [8:0]   header_length_o;
    wire [3:0]   header_tagID_o;
    wire [15:0]  header_requestID_o;
    wire [15:0]  header_completID_o;

    // Instantiate the DUT (Device Under Test)
    URP_PCIE_TOP uut (
        .clk(clk),
        .rst_n(rst_n),
        .payload_i(payload_i),
        .addr_i(addr_i),
        .header_fmt_i(header_fmt_i),
        .header_type_i(header_type_i),
        .header_tc_i(header_tc_i),
        .header_length_i(header_length_i),
        .header_tagID_i(header_tagID_i),
        .header_requestID_i(header_requestID_i),
        .header_completID_i(header_completID_i),
        .payload_o(payload_o),
        .addr_o(addr_o),
        .header_fmt_o(header_fmt_o),
        .header_type_o(header_type_o),
        .header_tc_o(header_tc_o),
        .header_length_o(header_length_o),
        .header_tagID_o(header_tagID_o),
        .header_requestID_o(header_requestID_o),
        .header_completID_o(header_completID_o)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Testbench logic
    initial begin
        // Initialize inputs
        rst_n = 0;
        payload_i = 0;
        addr_i = 0;
        header_fmt_i = 0;
        header_type_i = 0;
        header_tc_i = 0;
        header_length_i = 0;
        header_tagID_i = 0;
        header_requestID_i = 0;
        header_completID_i = 0;

        // Release reset
        #10;
        rst_n = 1;
        #10;
            // Test case 1
        payload_i = 128'hDEADBEEF1234567890ABCDEF12345678;
        addr_i = 30'h3F_FFFF;
        header_fmt_i = 3'b010;
        header_type_i = 5'b100010;
        header_tc_i = 3'b011;
        header_length_i = 9'h011000101;
        header_tagID_i = 4'hA;
        header_requestID_i = 16'hABCD;
        header_completID_i = 16'h1234;
        #10;

        // Test case 2
        payload_i = 128'hAAAAAAAA_BBBBBBBB_CCCCCCCC_DDDDDDDD;
        addr_i = 30'h0;
        header_fmt_i = 3'b001;
        header_type_i = 5'b00001;
        header_tc_i = 3'b010;
        header_length_i = 9'h0FF;
        header_tagID_i = 4'h5;
        header_requestID_i = 16'h4321;
        header_completID_i = 16'h5678;
        #10;

        // Test case 3
        payload_i = 128'hFFFFFFFF_EEEEEEEE_11111111_22222222;
        addr_i = 30'hABC_DEF;
        header_fmt_i = 3'b011;
        header_type_i = 5'b11111;
        header_tc_i = 3'b100;
        header_length_i = 9'h123;
        header_tagID_i = 4'hF;
        header_requestID_i = 16'hFFFF;
        header_completID_i = 16'h0000;
        #10;

        // Test case 4
        payload_i = 128'h12345678_9ABCDEF0_FEDCBA98_76543210;
        addr_i = 30'h555_5555;
        header_fmt_i = 3'b100;
        header_type_i = 5'b01010;
        header_tc_i = 3'b110;
        header_length_i = 9'h123;
        header_tagID_i = 4'h7;
        header_requestID_i = 16'h1357;
        header_completID_i = 16'h2468;
                // Test case 4
                       #10;
        payload_i = 128'h12345678_9ABCDEF0_FEDCBA98_76543210;
        addr_i = 30'h555_5555;
        header_fmt_i = 3'b110;
        header_type_i = 5'b01010;
        header_tc_i = 3'b111;
        header_length_i = 9'h123;
        header_tagID_i = 4'h7;
        header_requestID_i = 16'h1357;
        header_completID_i = 16'h2468;
        
                               #10;
        payload_i = 128'h12345678_9ABCDEF0_FEDCBA98_76543210;
        addr_i = 30'h555_5555;
        header_fmt_i = 3'b111;
        header_type_i = 5'b01110;
        header_tc_i = 3'b111;
        header_length_i = 9'h163;
        header_tagID_i = 4'h7;
        header_requestID_i = 16'h1357;
        header_completID_i = 16'h2468;
                               #10;
        payload_i = 128'h12345678_9ABCDEF0_FEDCBA98_76543210;
        addr_i = 30'h555_5555;
        header_fmt_i = 3'b010;
        header_type_i = 5'b01010;
        header_tc_i = 3'b000;
        header_length_i = 9'h123;
        header_tagID_i = 4'h7;
        header_requestID_i = 16'h1357;
        header_completID_i = 16'h2468;
                               #10;
        payload_i = 128'h12345678_9ABCDEF0_FEDCBA98_76543210;
        addr_i = 30'h555_5555;
        header_fmt_i = 3'b110;
        header_type_i = 5'b01010;
        header_tc_i = 3'b101;
        header_length_i = 9'h123;
        header_tagID_i = 4'h7;
        header_requestID_i = 16'h1357;
        header_completID_i = 16'h2468;
        #500;

        // Finish simulation
        $stop;
    end

endmodule
