module CRC_check (
    input logic [267:0] tlp_data_i, //TLP 데이터
    input logic tlp_data_valid_i, //TLP 데이터 유효 신호
    input logic clk,
    input logic rst_n,
    output logic [31:0] CRC // CRC

);

    logic [31:0] LCRC_reg;


    // LCRC 계산 모듈 인스턴스
    URP_PCIE_CRC32_GEN #(
        .DATA_WIDTH(224),
        .CRC_WIDTH(32)
    ) crc_gen (
        .data_i(tlp_data_i[255:32]), // TLP 데이터 입력
        .checksum_o(LCRC_reg) // 계산된 LCRC 출력
    );

    // CRC 계산 및 comp 신호 제어
   always_ff@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            CRC <= 32'b0; // 리셋 시 초기화

        end else if (tlp_data_valid_i && LCRC_reg[31:0] != 32'hC8F71A06) begin
            CRC <= LCRC_reg; // 유효한 데이터일 경우 LCRC_reg 값을 저장

        end
    end
    // dllp_o 계산: CRC 계산 완료 후에만 출력
    

       
        
    

endmodule