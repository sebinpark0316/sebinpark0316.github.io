module LCRC_gen (
input logic [223:0] tlp_data_i, //TLP 데이터
input logic tlp_data_valid_i, //TLP 데이터 유효 신호
input logic clk,
input logic rst_n,
output logic [31:0] LCRC // LCRC
);

logic [31:0] LCRC_reg;

// LCRC 계산 모듈 인스턴스
URP_PCIE_CRC32_GEN #(
.DATA_WIDTH(224),
.CRC_WIDTH(32)
) crc_gen (
.data_i(tlp_data_i), // TLP 데이터 입력
.checksum_o(LCRC_reg) // 계산된 LCRC 출력
);


assign LCRC = (!rst_n) ? 32'b0 : (tlp_data_valid_i ? LCRC_reg : LCRC);

endmodule