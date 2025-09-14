`timescale 1ns / 1ps

module URP_PCIE_RX_tb;

    // Clock and reset
    logic clk;
    logic rst_n;

    // Data link layer interface
    logic [267:0] rx_tlp_data_i;
    logic rx_tlp_valid_i;
    logic rx_tlp_ready_o;

    logic [31:0] dllp_o;
    logic dllp_valid_o;
    logic dllp_ready_i;

    // Transaction layer interface
    logic [127:0] payload_o;
    logic [29:0] addr_o;
    logic [2:0] header_fmt_o;
    logic [4:0] header_type_o;
    logic [2:0] header_tc_o;
    logic [8:0] header_length_o;
    logic [3:0] header_tagID_o;
    logic [15:0] header_requestID_o;
    logic [15:0] header_completID_o;

    // Instantiate the DUT (Device Under Test)
    URP_PCIE_RX dut (
        .clk(clk),
        .rst_n(rst_n),

        // Data link layer interface
        .rx_tlp_data_i(rx_tlp_data_i),
        .rx_tlp_valid_i(rx_tlp_valid_i),
        .rx_tlp_ready_o(rx_tlp_ready_o),

        .dllp_o(dllp_o),
        .dllp_valid_o(dllp_valid_o),
        .dllp_ready_i(dllp_ready_i),

        // Transaction layer interface
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
    always #5 clk = ~clk;

    // Testbench logic
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        rx_tlp_data_i = 268'b0;
        rx_tlp_valid_i = 0;
        dllp_ready_i = 0;
        
        #5       
          dllp_ready_i = 1;
        // Reset sequence
        #15 rst_n = 1;
                  dllp_ready_i = 1;
        // Test Case 1: Send valid TLP data
         #5;
        rx_tlp_data_i = {12'h000, 
                 3'b010,          // FMT
                 5'b00010,        // Type
                 3'b011,          // TC
                 9'b011000101,    // Length
                 8'b0000000,      // Reserved
                 4'b1111,         //ID
                 16'hABCD,        // Requester ID
                 16'h1234,        // Completion ID
                 30'h3F_FFFF,     // Address[31:2]
                 2'b00,           // Reserved
                 128'hDEADBEEF1234567890ABCDEF12345678// Payload 
                 ,32'h496FE297}; // 유효 CRC + ack
        rx_tlp_valid_i = 1;
        dllp_ready_i = 1;
         #10;
        rx_tlp_data_i = {12'h001, 
                 3'b110,          // FMT
                 5'b00010,        // Type
                 3'b111,          // TC
                 9'b000000101,    // Length
                 8'b0000000,      // Reserved
                 4'b1111,         //ID
                 16'hABCD,        // Requester ID
                 16'h1234,        // Completion ID
                 30'h3F_FFFF,     // Address[31:2]
                 2'b00,           // Reserved
                 128'hDEADBEEF1234567890ABCDEF12345678// Payload 
                 ,32'h0E0931}; // 유효 CRC + ack
        rx_tlp_valid_i = 1;
        // Test Case 2: Read DLLP
        #10;
          rx_tlp_data_i = {12'h001, 
                 3'b110,          // FMT
                 5'b01010,        // Type
                 3'b101,          // TC
                 9'b000000101,    // Length
                 8'b0000000,      // Reserved
                 4'b1111,         //ID
                 16'hABCD,        // Requester ID
                 16'h1234,        // Completion ID
                 30'h3F_FFFF,     // Address[31:2]
                 2'b00,           // Reserved
                 128'hDEADBEEF1234567890ABCDEF12345678// Payload 
                 ,32'h327E885B}; // 유효 CRC + ack


          #10;
          rx_tlp_data_i = {12'h002, 
                 3'b110,          // FMT
                 5'b01110,        // Type
                 3'b100,          // TC
                 9'b000000101,    // Length
                 8'b0000000,      // Reserved
                 4'b1111,         //ID
                 16'hABCD,        // Requester ID
                 16'h1234,        // Completion ID
                 30'h3F_FFFF,     // Address[31:2]
                 2'b00,           // Reserved
                 128'hDEADBEEF1234567890ABCDEF12345678// Payload 
                 ,32'h2C454F6E}; // 유효 CRC + ack
;

        rx_tlp_valid_i = 1;
        #10;


        // Monitor outputs for a while
        #100;

    end

  
endmodule
