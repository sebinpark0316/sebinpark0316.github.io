module URP_PCIE_RX_TRANSACTION_LAYER (
    input   logic                   clk,
    input   logic                   rst_n,

    // Data link layer interface
    input   logic   [223:0]         tlp_data_i,
    input   logic                   tlp_data_valid_i,
    output  logic                   tlp_data_ready_o,

    output  logic   [127:0]         payload_o,
    output  logic   [29:0]          addr_o,
    output  logic   [2:0]           header_fmt_o,
    output  logic   [4:0]           header_type_o,
    output  logic   [2:0]           header_tc_o,
    output  logic   [8:0]           header_length_o,
    output  logic   [3:0]           header_tagID_o,
    output  logic   [15:0]          header_requestID_o,
    output  logic   [15:0]          header_completID_o
);

    /*
    FILL YOUR CODES HERE
        FIFO*2 / Arbiter / De_Packetizer
    */


/////////////////////////////FIFO///////////////////////////////////

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
    .wren_i(tlp_data_valid_i && (tlp_data_i[215:213] <= 3'b011)), // Send to VC0 if TC <= 3
    .wdata_i(tlp_data_i),
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
    .wren_i(tlp_data_valid_i && (tlp_data_i[215:213] >= 3'b100)), // Send to VC1 if TC >= 4
    .wdata_i(tlp_data_i),
    .rden_i(fifo_vc1_rden_i),
    .rdata_o(fifo_vc1_data),
    .full_o(fifo_vc1_full),
    .empty_o(fifo_vc1_empty)
);

assign tlp_data_ready_o = 
    (!fifo_vc0_full ||  !fifo_vc1_full);

//////////////////////ARBITER///////////////////////
// Arbiter input signals
logic [1:0] src_valid_i;  // Valid signals from VC1 and VC0
logic [223:0] src_data_i [1:0];  // Data from VC1 and VC0
logic dst_valid_o;

always_comb begin
    src_valid_i = {~fifo_vc1_empty, ~fifo_vc0_empty};  // Set valid signals based on empty states
    src_data_i[0] = fifo_vc0_data;  // Set data from VC1
    src_data_i[1] = fifo_vc1_data;  // Set data from VC0
end

// Arbiter output signals
logic dst_valid_o;
logic [223:0] dst_data_o;
logic [1:0] src_ready_o;


RX_URP_PCIE_ARBITER #(
    .N_MASTER(2), // Two masters: VC0, VC1
    .DATA_SIZE(224)
) arbiter (
    .clk(clk),
    .rst_n(rst_n),
    .src_valid_i(src_valid_i),
    .src_ready_o({fifo_vc1_rden_i, fifo_vc0_rden_i}), // Assuming both VC0 and VC1 can be ready to transmit
    .src_data_i(src_data_i),
    .dst_valid_o(dst_valid_o),
    .dst_ready_i(1'b1),                      ///////////////////만약 두 개의 PCIe가 서로 signal을 주고 받는다면 그때의 TX_transaction layer의 valid가 들어가면 됨!!     
    .dst_data_o(dst_data_o)
);

//////////////////// De_Packetizer////////////////////////

// De-Packetizer logic for TLP Data
assign payload_o          = dst_valid_o ? dst_data_o[127:0] : 128'b0;          // [127:0] Payload
assign addr_o             = dst_valid_o ? dst_data_o[175:146] : 30'b0;         // [175:146] Address
assign header_fmt_o       = dst_valid_o ? dst_data_o[223:221] : 3'b0;          // [223:221] Format
assign header_type_o      = dst_valid_o ? dst_data_o[220:216] : 5'b0;          // [220:216] Type
assign header_tc_o        = dst_valid_o ? dst_data_o[215:213] : 3'b0;          // [215:213] Traffic Class
assign header_length_o    = dst_valid_o ? dst_data_o[212:204] : 9'b0;          // [212:204] Length
assign header_tagID_o     = dst_valid_o ? dst_data_o[195:192] : 4'b0;          // [195:192] Tag ID
assign header_requestID_o = dst_valid_o ? dst_data_o[191:176] : 16'b0;         // [191:176] Requester ID
assign header_completID_o = dst_valid_o ? dst_data_o[159:144] : 16'b0;
endmodule
