module packetizer (
input logic clk,
input logic rst_n,
input logic tlp_data_valid_i, // TLP 데이터 유효 신호
input logic [223:0] tlp_data_i, // TLP 데이터 입력
output logic [267:0] link_packet // 순차번호 + TLP + LCRC
);

logic [11:0] sequence_num; // 순차번호
logic [223:0] tlp_data; // 버퍼에 저장된 TLP
logic [31:0] LCRC; // LCRC
logic valid_started;
// `sequence_gen` 인스턴스
sequence_gen u_sequence_gen (
.clk(clk),
.rst_n(rst_n),
.tlp_data_i(tlp_data_i),
.tlp_data_valid_i(tlp_data_valid_i),
.sequence_num(sequence_num)
);

// `TLP_buffer` 인스턴스
TLP_buffer u_tlp_buffer (
.clk(clk),
.rst_n(rst_n),
.tlp_data_i(tlp_data_i),
.tlp_data_valid_i(tlp_data_valid_i),
.tlp_data(tlp_data)
);

// `LCRC_gen` 인스턴스
LCRC_gen u_lcrc_gen (
.clk(clk),
.rst_n(rst_n),
.tlp_data_i(tlp_data_i),
.tlp_data_valid_i(tlp_data_valid_i),
.LCRC(LCRC)
);

   // valid_started 상태 추적
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_started <= 1'b0;
        end else if (tlp_data_valid_i) begin
            valid_started <= 1'b1; // 유효 신호 활성화 시 상태 업데이트
        end
    end
    


    // link_packet 생성
    assign link_packet = (valid_started && tlp_data_valid_i) ? 
                         {sequence_num, tlp_data, LCRC} : 267'b0;

endmodule