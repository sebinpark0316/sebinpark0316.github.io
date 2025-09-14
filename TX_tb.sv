`timescale 1ns / 1ps

module tb_URP_PCIE_TX;

    // Parameters for the testbench
    parameter CLK_PERIOD = 10;  // Clock period in ns

    // Clock and Reset
    reg clk;
    reg rst_n;

    // Transaction Layer Interface Signals
    reg [127:0] payload_i;
    reg [29:0] addr_i;
    reg [2:0] header_fmt_i;
    reg [4:0] header_type_i;
    reg [2:0] header_tc_i;
    reg [8:0] header_length_i;
    reg [15:0] header_requestID_i;
    reg [15:0] header_completID_i;
    reg [3:0] header_tagID_i;
    // Data Link Layer Interface Signals
    wire [267:0] rx_tlp_data_o;
    wire rx_tlp_valid_o;
    reg rx_tlp_ready_i;

    reg [31:0] dllp_i;
    reg dllp_valid_i;
    wire dllp_ready_o;

    // Instantiate the URP_PCIE_TX module
    URP_PCIE_TX uut (
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
        .rx_tlp_data_o(rx_tlp_data_o),
        .rx_tlp_valid_o(rx_tlp_valid_o),
        .rx_tlp_ready_i(rx_tlp_ready_i),
        .dllp_i(dllp_i),
        .dllp_valid_i(dllp_valid_i),
        .dllp_ready_o(dllp_ready_o)
    );

    // Clock Generation
    always begin
        # (CLK_PERIOD / 2) clk = ~clk;  // Toggle clock every half period
    end

    // Test Sequence
    initial begin
        // Initial values
        clk = 0;
        rst_n = 0;
        payload_i = 128'b0;
        addr_i = 30'hABCDEF;
        header_fmt_i = 3'b0;
        header_type_i = 5'b0;
        header_tc_i = 3'b0;
        header_length_i = 9'b000000000;
        header_tagID_i = 4'b0000;
        header_requestID_i = 16'b0;
        header_completID_i = 16'b0;
        dllp_i = 0;
        dllp_valid_i = 0;
        rx_tlp_ready_i = 0;

        // Reset the DUT
        # (CLK_PERIOD * 2);
        rx_tlp_ready_i = 1;
        dllp_valid_i = 1;

        // Test 1: Send a TLP with some values
        # (CLK_PERIOD);
                rst_n = 1;
        dllp_i = {8'h00, 24'b0};
        payload_i = 128'hDEADBEEFDEADBEEFDEADBEEFDEADBEEF;  // Random payload data
        addr_i = 30'hABCDEF;  // Random address
        header_fmt_i = 3'b101; // Random format
        header_type_i = 5'b10001; // Random type
        header_tc_i = 3'b010;   // Traffic class
        header_length_i = 9'b000001000; // Length field (non-zero)
        header_tagID_i = 4'b1101;  // Random Tag ID
        header_requestID_i = 16'hA1B2; // Requester ID
        header_completID_i = 16'hC3D4; // Completion ID
      
        # (CLK_PERIOD);
        dllp_i = {8'h00, 24'b0};
        payload_i = 128'hDEADBEEFDEADBEEFDEADBEEFDEADBEEF;  // Random payload data
        addr_i = 30'hABCDEF;  // Random address
        header_fmt_i = 3'b110; // Random format
        header_type_i = 5'b10001; // Random type
        header_tc_i = 3'b010;   // Traffic class
        header_length_i = 9'b000001000; // Length field (non-zero)
        header_tagID_i = 4'b1101;  // Random Tag ID
        header_requestID_i = 16'hA1B2; // Requester ID
        header_completID_i = 16'hC3D4; // Completion ID
      
        # (CLK_PERIOD);
        dllp_i = {8'h00, 24'b0};
        payload_i = 128'hDEADBEEFDEADBEEFDEADBEEFDEADBEEF;  // Random payload data
        addr_i = 30'hABCDEF;  // Random address
        header_fmt_i = 3'b111; // Random format
        header_type_i = 5'b11001; // Random type
        header_tc_i = 3'b010;   // Traffic class
        header_length_i = 9'b000001000; // Length field (non-zero)
        header_tagID_i = 4'b1101;  // Random Tag ID
        header_requestID_i = 16'hA1B2; // Requester ID
        header_completID_i = 16'hC3D4; // Completion ID

        # (CLK_PERIOD);
        dllp_i = {8'h00, 24'b0};
        payload_i = 128'hDEADBEEFDEADBEEFDEADBEEFDEADBEEF;  // Random payload data
        addr_i = 30'hABCDEF;  // Random address
        header_fmt_i = 3'b100; // Random format
        header_type_i = 5'b11001; // Random type
        header_tc_i = 3'b010;   // Traffic class
        header_length_i = 9'b000001000; // Length field (non-zero)
        header_tagID_i = 4'b1101;  // Random Tag ID
        header_requestID_i = 16'hA1B2; // Requester ID
        header_completID_i = 16'hC3D4; // Completion ID
        // Extend simulation duration
        # (CLK_PERIOD * 100);
        $finish;
    end

    // Monitor outputs
    initial begin
        $monitor("Time: %t | rx_tlp_data_o: %h | rx_tlp_valid_o: %b | dllp_ready_o: %b", 
                 $time, rx_tlp_data_o, rx_tlp_valid_o, dllp_ready_o);
    end

endmodule