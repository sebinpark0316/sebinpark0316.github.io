module URP_TX_TRANSACTION_LAYER (
    input   logic                   clk,
    input   logic                   rst_n,

    // Transaction Layer inputs
    input   logic   [127:0]         payload_i,
    input   logic   [29:0]          addr_i,
    input   logic   [2:0]           header_fmt_i,
    input   logic   [4:0]           header_type_i,
    input   logic   [2:0]           header_tc_i,
    input   logic   [8:0]           header_length_i,
    input   logic   [3:0]           header_tagID_i,
    input   logic   [15:0]          header_requestID_i,
    input   logic   [15:0]          header_completID_i,

    // Transaction Layer outputs
    output  logic   [223:0]         tlp_o,
    output  logic                   tlp_valid_o,
    input   logic                    tlp_ready_i
);

///////////////////////////////////// Packetizer - TLP Packet Construction

// TLP Packet construction
logic   [223:0]    tlp_packet;
logic              packet_valid;

always_comb begin
    tlp_packet = {
        header_fmt_i,          // [223:221] Format  
        header_type_i,         // [220:216] Type 
        header_tc_i,           // [215:213] Traffic Class 
        header_length_i,       // [212:204] Length 
        8'b0,                  // [203:196] Reserved  
        header_tagID_i,        // [195:192] Tag ID   
        header_requestID_i,    // [191:176] Requester ID
        addr_i,                // [175:146] Address
        18'b0,                 // [145:128] Reserved
        payload_i              // [127:0] Payload
    };
    packet_valid = (header_length_i != 9'b0); // Check if length is not zero
end

///////////////////////////////////// FIFO Modules for VC0 and VC1

// FIFO control signals for VC0 and VC1
logic fifo_vc0_full, fifo_vc1_full;
logic fifo_vc0_empty, fifo_vc1_empty;
logic [223:0] fifo_vc0_data, fifo_vc1_data;
logic fifo_vc0_rden_i, fifo_vc1_rden_i;


URP_PCIE_FIFO #(
    .DEPTH_LG2(4), 
    .DATA_WIDTH(224)
) fifo_vc0 (
    .clk(clk),
    .rst_n(rst_n),
    .wren_i(packet_valid && (header_tc_i <= 3)), // Send to VC0 if TC <= 3
    .wdata_i(tlp_packet),
    .rden_i(fifo_vc0_rden_i),
    .rdata_o(fifo_vc0_data),
    .full_o(fifo_vc0_full),
    .empty_o(fifo_vc0_empty)
);

URP_PCIE_FIFO #(
    .DEPTH_LG2(4), 
    .DATA_WIDTH(224)
) fifo_vc1 (
    .clk(clk),
    .rst_n(rst_n),
    .wren_i(packet_valid && (header_tc_i >= 4)), // Send to VC1 if TC >= 4
    .wdata_i(tlp_packet),
    .rden_i(fifo_vc1_rden_i),
    .rdata_o(fifo_vc1_data),
    .full_o(fifo_vc1_full),
    .empty_o(fifo_vc1_empty)
);

///////////////////////////////////// Arbiter Module

// Arbiter input signals
logic [1:0] src_valid_i;  // Valid signals from VC1 and VC0
logic [223:0] src_data_i [1:0];  // Data from VC1 and VC0

always_comb begin
    src_valid_i = {~fifo_vc1_empty, ~fifo_vc0_empty};  // Set valid signals based on empty states
    src_data_i[0] = fifo_vc1_data;  // Set data from VC1
    src_data_i[1] = fifo_vc0_data;  // Set data from VC0
end

// Arbiter output signals
logic dst_valid_o;
logic [223:0] dst_data_o;
logic [1:0] src_ready_o;

URP_PCIE_ARBITER #(
    .N_MASTER(2), // Two masters: VC0, VC1
    .DATA_SIZE(224)
) arbiter (
    .clk(clk),
    .rst_n(rst_n),
    .src_valid_i(src_valid_i),
    .src_ready_o({fifo_vc0_rden_i, fifo_vc1_rden_i}),
    .src_data_i(src_data_i),
    .dst_valid_o(dst_valid_o),
    .dst_ready_i(tlp_ready_i),                                      //data link의 ready signal로 바꾸기!!
    .dst_data_o(dst_data_o)
);

///////////////////////////////////// Final Output

// Final output TLP data from arbiter using always_ff
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tlp_o <= {224{1'b0}};  // Reset the output data to 0
        tlp_valid_o <= 1'b0;   // Reset the valid signal to 0
    end else if (tlp_ready_i) begin
        tlp_o <= dst_data_o;       // Update TLP data output
        tlp_valid_o <= dst_valid_o; // Update TLP valid output
    end
    else begin
        tlp_o <= tlp_o;
        tlp_valid_o <= 1'b0;
    end
end


endmodule