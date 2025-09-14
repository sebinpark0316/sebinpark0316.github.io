module URP_TX_DATA_LINK_LAYER
(
    input   logic                   clk,
    input   logic                   rst_n,

    // Transaction layer interface
    input   logic [223:0]           tlp_data_i,
    input   logic                   tlp_data_valid_i,
    output  logic                   tlp_data_ready_o,                       ///if NAK tlp_data_ready_o를 0으로 바꿔줘야함

    // RX interface
    output  logic [267:0]          tlp_data_o,
   output  logic                   tlp_data_valid_o,
    input   logic                    tlp_data_ready_i,
    input   logic [31:0]            dllp_i,  
    input   logic                    dllp_valid_i,
    output  logic                   dllp_ready_o 
);

 logic [267:0] link_packet; 

 logic comp;
    // Packetizer 인스턴스
    packetizer u_packetizer (
        .clk(clk),
        .rst_n(rst_n),
        .tlp_data_valid_i(tlp_data_valid_i),
        .tlp_data_i(tlp_data_i),
        .link_packet(link_packet)
    );

    // Replay Buffer 인스턴스
    replay_buffer u_replay_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .dllp_i(dllp_i),
        .dllp_valid_i(dllp_valid_i),

        .link_packet(link_packet),
        .tlp_data_o(tlp_data_o), // 최종 출력
        .comp(comp)
    );
    



assign tlp_data_valid_o = (rst_n && tlp_data_o!=268'b0) ? 1'b1 : 1'b0;

assign tlp_data_ready_o = (rst_n && dllp_i[31:24] == 8'h00) ? 1'b1 : 1'b0;

assign dllp_ready_o = (rst_n && link_packet!=268'b0 && comp) ? 1'b1 : 1'b0;
endmodule
